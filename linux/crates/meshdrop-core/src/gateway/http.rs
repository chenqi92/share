//! 极简 HTTP/1.1 处理：手写 header parse → 路由：
//!   GET  /                     → 内嵌 fallback HTML
//!   GET  /api/v1/version       → JSON 探针
//!   POST /api/v1/pair          → 浏览器输入 6 字符码，校验后下发 session token
//!   WS   /api/v1/control       → 升级为 WebSocket（pairing.rs 校验 cookie / Bearer）
//!
//! 本模块不依赖 hyper —— 手解析够用即可（companion-bridges §4.3 没有要求复杂 HTTP）。

use crate::gateway::pairing::PairingGate;
use crate::gateway::ws;
use crate::ShareEngine;
use anyhow::{Context, Result};
use log::{debug, info, warn};
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio_rustls::server::TlsStream;
use tokio::net::TcpStream;

const FALLBACK_HTML: &str = include_str!("../../../../data/web-fallback/index.html");

pub struct Request<'a> {
    pub method: &'a str,
    pub path: &'a str,
    pub headers: Vec<(String, String)>,
}

impl<'a> Request<'a> {
    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers.iter()
            .find(|(k, _)| k.eq_ignore_ascii_case(name))
            .map(|(_, v)| v.as_str())
    }
}

pub async fn handle(
    mut tls: TlsStream<TcpStream>,
    engine: ShareEngine,
    gate: Arc<PairingGate>,
) -> Result<()> {
    // 读 HTTP 头（最多 8 KiB）。body 由具体路由按 Content-Length 自己接着读。
    let mut buf = vec![0u8; 8192];
    let mut filled = 0usize;
    let header_end = loop {
        let n = tls.read(&mut buf[filled..]).await.context("read header")?;
        if n == 0 { anyhow::bail!("eof before header"); }
        filled += n;
        if let Some(idx) = find_double_crlf(&buf[..filled]) {
            break idx + 4;
        }
        if filled == buf.len() {
            anyhow::bail!("header too large");
        }
    };

    let mut headers = [httparse::EMPTY_HEADER; 32];
    let mut req = httparse::Request::new(&mut headers);
    let parsed = req.parse(&buf[..header_end]).context("httparse")?;
    if !parsed.is_complete() {
        anyhow::bail!("incomplete header");
    }
    let method = req.method.unwrap_or("").to_string();
    let path = req.path.unwrap_or("").to_string();
    let hdrs: Vec<(String, String)> = req.headers.iter()
        .map(|h| (h.name.to_string(),
                   String::from_utf8_lossy(h.value).to_string()))
        .collect();
    let r = Request { method: &method, path: &path, headers: hdrs };

    debug!("gateway request {} {}", r.method, r.path);

    // WebSocket upgrade
    if is_ws_upgrade(&r) && r.path == "/api/v1/control" {
        return ws::accept(tls, &r, engine, gate).await;
    }

    let body_after_header = &buf[header_end..filled];

    match (r.method, r.path) {
        ("GET", "/") | ("GET", "/index.html") => {
            write_response(&mut tls, 200, "OK",
                &[("Content-Type", "text/html; charset=utf-8"),
                  ("Cache-Control", "no-store")],
                FALLBACK_HTML.as_bytes()).await
        }
        ("GET", "/api/v1/version") => {
            let body = format!(r#"{{"v":1,"app":"meshdrop-linux-gui","port":{}}}"#,
                engine.listen_port);
            write_response(&mut tls, 200, "OK",
                &[("Content-Type", "application/json")], body.as_bytes()).await
        }
        ("POST", "/api/v1/pair") => {
            let body = read_body(&mut tls, &r, body_after_header).await?;
            let code: String = serde_json::from_slice::<serde_json::Value>(&body)
                .ok()
                .and_then(|v| v.get("code").and_then(|c| c.as_str().map(String::from)))
                .unwrap_or_default();
            match gate.try_pair(&code) {
                Some(token) => {
                    let payload = serde_json::json!({"ok": true, "token": token});
                    write_response(&mut tls, 200, "OK",
                        &[("Content-Type", "application/json"),
                          ("Set-Cookie", &format!("meshdrop_session={}; HttpOnly; Path=/; Max-Age=86400; SameSite=Strict", token))],
                        payload.to_string().as_bytes()).await
                }
                None => {
                    let payload = serde_json::json!({"ok": false, "error": "invalid_code"});
                    write_response(&mut tls, 401, "Unauthorized",
                        &[("Content-Type", "application/json")],
                        payload.to_string().as_bytes()).await
                }
            }
        }
        _ => {
            write_response(&mut tls, 404, "Not Found",
                &[("Content-Type", "text/plain")],
                b"404\n").await
        }
    }
}

fn is_ws_upgrade(r: &Request) -> bool {
    r.method.eq_ignore_ascii_case("GET")
        && r.header("Upgrade").map(|v| v.eq_ignore_ascii_case("websocket")).unwrap_or(false)
}

fn find_double_crlf(buf: &[u8]) -> Option<usize> {
    buf.windows(4).position(|w| w == b"\r\n\r\n")
}

async fn read_body(
    tls: &mut TlsStream<TcpStream>,
    r: &Request<'_>,
    already: &[u8],
) -> Result<Vec<u8>> {
    let len: usize = r.header("Content-Length")
        .and_then(|v| v.trim().parse().ok())
        .unwrap_or(0);
    if len > 1024 * 1024 {
        warn!("rejecting body > 1MB");
        anyhow::bail!("body too large");
    }
    let mut body = Vec::with_capacity(len);
    body.extend_from_slice(already);
    while body.len() < len {
        let mut chunk = vec![0u8; (len - body.len()).min(8192)];
        let n = tls.read(&mut chunk).await?;
        if n == 0 { break; }
        body.extend_from_slice(&chunk[..n]);
    }
    body.truncate(len);
    Ok(body)
}

async fn write_response(
    tls: &mut TlsStream<TcpStream>,
    code: u16, reason: &str,
    headers: &[(&str, &str)],
    body: &[u8],
) -> Result<()> {
    let mut h = format!("HTTP/1.1 {} {}\r\n", code, reason);
    let has_len = headers.iter().any(|(k, _)| k.eq_ignore_ascii_case("Content-Length"));
    for (k, v) in headers {
        h.push_str(&format!("{}: {}\r\n", k, v));
    }
    if !has_len {
        h.push_str(&format!("Content-Length: {}\r\n", body.len()));
    }
    h.push_str("Connection: close\r\n\r\n");
    tls.write_all(h.as_bytes()).await?;
    tls.write_all(body).await?;
    tls.flush().await?;
    Ok(())
}

#[allow(dead_code)]
fn log_init_done() { info!("gateway http module ready"); }
