//! 极简 HTTP/1.1 处理：手写 header parse → 路由：
//!   GET  /                       → 内嵌 fallback HTML
//!   GET  /api/v1/version         → JSON 探针
//!   POST /api/v1/pair            → 浏览器输入 6 字符码，校验后下发 session token
//!   WS   /api/v1/control         → 升级为 WebSocket（pairing.rs 校验 cookie / Bearer）
//!   POST /api/v1/upload          → multipart 上传到 LocalAppData/uploads，返回 token
//!   GET  /api/v1/download/<id>   → 流式下载已接收的文件
//!
//! 本模块不依赖 hyper —— 手解析够用即可（companion-bridges §4.3 没有要求复杂 HTTP）。

use crate::gateway::pairing::PairingGate;
use crate::gateway::ws;
use crate::history::HistoryKind;
use crate::ShareEngine;
use anyhow::{Context, Result};
use log::{debug, info, warn};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio_rustls::server::TlsStream;
use tokio::net::TcpStream;
use uuid::Uuid;

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

    // 日志只记 method + 路径前缀，剥掉 query string —— 早期版本曾支持 ?token= 兜底，
    // 不能让 token 经 URL 落进日志。
    debug!("gateway request {} {}", r.method, path_for_log(&path));

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
        ("POST", "/api/v1/upload") => {
            // 鉴权（companion-bridges.md §4.3）—— 沿用 ws.rs 的 extract_token 逻辑
            if !is_authenticated(&r, &gate) {
                return write_unauthorized(&mut tls).await;
            }
            handle_upload(&mut tls, &r, body_after_header).await
        }
        (method, path) if method == "GET" && path.starts_with("/api/v1/download/") => {
            if !is_authenticated(&r, &gate) {
                return write_unauthorized(&mut tls).await;
            }
            handle_download(&mut tls, path, &engine).await
        }
        _ => {
            write_response(&mut tls, 404, "Not Found",
                &[("Content-Type", "text/plain")],
                b"404\n").await
        }
    }
}

// ─── 鉴权 ──────────────────────────────────────────────────────────

fn is_authenticated(r: &Request, gate: &PairingGate) -> bool {
    if let Some(token) = extract_token(r) {
        gate.is_valid_session(&token)
    } else {
        false
    }
}

fn extract_token(r: &Request) -> Option<String> {
    // token 只走 Cookie / header，绝不接受 query string —— 防止经 URL 泄漏 / 落日志。
    // 1. cookie meshdrop_session
    if let Some(cookie) = r.header("Cookie") {
        for part in cookie.split(';') {
            let kv = part.trim();
            if let Some(rest) = kv.strip_prefix("meshdrop_session=") {
                return Some(rest.to_string());
            }
        }
    }
    // 2. header x-meshdrop-token
    if let Some(t) = r.header("x-meshdrop-token") {
        if !t.is_empty() { return Some(t.to_string()); }
    }
    None
}

/// 去掉 query string 的路径，用于日志（避免历史上的 ?token= 落盘）。
fn path_for_log(path: &str) -> &str {
    path.split('?').next().unwrap_or(path)
}

async fn write_unauthorized(tls: &mut TlsStream<TcpStream>) -> Result<()> {
    write_response(tls, 401, "Unauthorized",
        &[("Content-Type", "application/json")],
        br#"{"ok":false,"error":"unauthorized"}"#).await
}

// ─── /api/v1/upload ──────────────────────────────────────────────

async fn handle_upload(
    tls: &mut TlsStream<TcpStream>,
    r: &Request<'_>,
    already: &[u8],
) -> Result<()> {
    let content_type = r.header("Content-Type").unwrap_or("");
    let boundary = match parse_boundary(content_type) {
        Some(b) => b,
        None => {
            return write_response(tls, 400, "Bad Request",
                &[("Content-Type", "application/json")],
                br#"{"ok":false,"error":"missing_boundary"}"#).await;
        }
    };
    // multipart 浏览器上传上限 512 MiB（companion-bridges 浏览器侧场景，不走设备直传的
    // 4 GiB 单文件上限）。按 Content-Length 校验上限但不 with_capacity 预分配，避免 OOM。
    const UPLOAD_LIMIT: usize = 512 * 1024 * 1024;
    let body = read_body_with_limit(tls, r, already, UPLOAD_LIMIT).await?;

    let part = match find_first_file_part(&body, &boundary) {
        Some(p) => p,
        None => {
            return write_response(tls, 400, "Bad Request",
                &[("Content-Type", "application/json")],
                br#"{"ok":false,"error":"multipart_malformed"}"#).await;
        }
    };

    let dir = upload_dir();
    if let Err(e) = tokio::fs::create_dir_all(&dir).await {
        warn!("mkdir uploads failed: {e}");
        return write_response(tls, 500, "Internal Error",
            &[("Content-Type", "application/json")],
            br#"{"ok":false,"error":"io"}"#).await;
    }
    // 只取文件名最后一段，剥掉任何路径成分（防 ../ 或绝对路径穿越）。
    let safe_name = sanitize_filename(&part.filename);
    let target = dir.join(format!("{}-{}", Uuid::new_v4(), safe_name));
    // canonicalize 校验：落盘目标必须仍在 upload_dir 内（防符号链接 / 残留穿越）。
    let canon_dir = match tokio::fs::canonicalize(&dir).await {
        Ok(d) => d,
        Err(e) => {
            warn!("canonicalize uploads dir failed: {e}");
            return write_response(tls, 500, "Internal Error",
                &[("Content-Type", "application/json")],
                br#"{"ok":false,"error":"io"}"#).await;
        }
    };
    if target.parent().map(|p| p.to_path_buf()) != Some(canon_dir) {
        warn!("upload target escapes uploads dir: {}", target.display());
        return write_response(tls, 400, "Bad Request",
            &[("Content-Type", "application/json")],
            br#"{"ok":false,"error":"bad_filename"}"#).await;
    }
    if let Err(e) = tokio::fs::write(&target, &part.body).await {
        warn!("write upload failed: {e}");
        return write_response(tls, 500, "Internal Error",
            &[("Content-Type", "application/json")],
            br#"{"ok":false,"error":"io"}"#).await;
    }
    let token = target.to_string_lossy().to_string();
    // 转义 JSON 字符串
    let json_token = token.replace('\\', "\\\\").replace('"', "\\\"");
    let body_resp = format!(r#"{{"ok":true,"token":"{json_token}"}}"#);
    write_response(tls, 200, "OK",
        &[("Content-Type", "application/json")],
        body_resp.as_bytes()).await
}

pub(crate) fn upload_dir() -> PathBuf {
    let base = dirs::data_local_dir()
        .or_else(dirs::home_dir)
        .unwrap_or_else(|| PathBuf::from("/tmp"));
    base.join("MeshDrop").join("uploads")
}

/// 把客户端给的 filename 收敛成一个安全的单段文件名：
/// 取最后一段（按 `/` 与 `\` 切分），剔除控制字符，拒绝 `.`/`..`/空。
fn sanitize_filename(raw: &str) -> String {
    let last = raw
        .rsplit(['/', '\\'])
        .next()
        .unwrap_or("")
        .trim()
        .trim_matches('\u{0}');
    let cleaned: String = last.chars().filter(|c| !c.is_control()).collect();
    if cleaned.is_empty() || cleaned == "." || cleaned == ".." {
        format!("upload-{}", Uuid::new_v4())
    } else {
        cleaned
    }
}

// ─── /api/v1/download/<historyId> ────────────────────────────────

async fn handle_download(
    tls: &mut TlsStream<TcpStream>,
    path: &str,
    engine: &ShareEngine,
) -> Result<()> {
    let id_str = path.trim_start_matches("/api/v1/download/").split('?').next().unwrap_or("");
    let history_id = match Uuid::parse_str(id_str) {
        Ok(u) => u,
        Err(_) => {
            return write_response(tls, 400, "Bad Request",
                &[("Content-Type", "application/json")],
                br#"{"ok":false,"error":"bad_history_id"}"#).await;
        }
    };
    let history = engine.history_rx().borrow().clone();
    let lookup = history.iter().find_map(|h| {
        if h.id != history_id { return None; }
        if !matches!(h.direction, crate::history::TransferDirection::Incoming) { return None; }
        match &h.kind {
            HistoryKind::File { name, path: Some(p), .. } => Some((name.clone(), p.clone())),
            _ => None,
        }
    });
    let (name, file_path) = match lookup {
        Some(t) => t,
        None => {
            return write_response(tls, 404, "Not Found",
                &[("Content-Type", "application/json")],
                br#"{"ok":false,"error":"file_not_found"}"#).await;
        }
    };
    let meta = match tokio::fs::metadata(&file_path).await {
        Ok(m) => m,
        Err(_) => {
            return write_response(tls, 410, "Gone",
                &[("Content-Type", "application/json")],
                br#"{"ok":false,"error":"file_gone"}"#).await;
        }
    };
    let size = meta.len();
    let safe_name = rfc5987_encode(&name);
    let head = format!(
        "HTTP/1.1 200 OK\r\n\
         Content-Type: application/octet-stream\r\n\
         Content-Length: {size}\r\n\
         Content-Disposition: attachment; filename*=UTF-8''{safe_name}\r\n\
         Server: MeshDrop-Gateway-Linux/0.1\r\n\
         Connection: close\r\n\r\n"
    );
    tls.write_all(head.as_bytes()).await?;
    // 64 KiB 分块
    let mut f = File::open(&file_path).await?;
    let mut buf = vec![0u8; 64 * 1024];
    loop {
        let n = f.read(&mut buf).await?;
        if n == 0 { break; }
        tls.write_all(&buf[..n]).await?;
    }
    tls.flush().await?;
    Ok(())
}

/// RFC 5987 编码：把任意 UTF-8 文件名编码进 Content-Disposition: filename*=UTF-8''<encoded>
fn rfc5987_encode(s: &str) -> String {
    let mut out = String::with_capacity(s.len() * 3);
    for b in s.as_bytes() {
        if matches!(b, b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'~') {
            out.push(*b as char);
        } else {
            out.push_str(&format!("%{:02X}", b));
        }
    }
    out
}

// ─── Multipart 极简解析 ──────────────────────────────────────────

struct FilePart {
    filename: String,
    body: Vec<u8>,
}

fn parse_boundary(header: &str) -> Option<String> {
    let lower = header.to_ascii_lowercase();
    if !lower.starts_with("multipart/form-data") { return None; }
    let idx = lower.find("boundary=")?;
    let rest = &header[idx + "boundary=".len()..];
    let mut s = rest.trim();
    if let Some(stripped) = s.strip_prefix('"') {
        s = stripped;
        if let Some(end) = s.find('"') { return Some(s[..end].to_string()); }
        return Some(s.to_string());
    }
    if let Some(end) = s.find(|c: char| c == ';' || c.is_whitespace()) {
        return Some(s[..end].to_string());
    }
    Some(s.to_string())
}

fn find_first_file_part(body: &[u8], boundary: &str) -> Option<FilePart> {
    let delim = format!("--{boundary}").into_bytes();
    let end_sentinel = format!("\r\n--{boundary}").into_bytes();
    let crlf = b"\r\n";
    let d_crlf = b"\r\n\r\n";

    // 找第一个 boundary
    let first = find_slice(body, &delim)?;
    let mut cursor = first + delim.len();
    if body.len() >= cursor + 2 && &body[cursor..cursor + 2] == crlf {
        cursor += 2;
    }
    while cursor < body.len() {
        let header_end = find_slice(&body[cursor..], d_crlf)?;
        let header_text = std::str::from_utf8(&body[cursor..cursor + header_end]).ok()?;
        cursor += header_end + d_crlf.len();
        let mut filename = String::new();
        for line in header_text.split("\r\n") {
            if line.is_empty() { continue; }
            let low = line.to_ascii_lowercase();
            if low.starts_with("content-disposition:") {
                if let Some(idx) = low.find("filename=") {
                    let mut rest = &line[idx + "filename=".len()..];
                    if let Some(stripped) = rest.strip_prefix('"') {
                        rest = stripped;
                        if let Some(end) = rest.find('"') {
                            filename = rest[..end].to_string();
                        }
                    } else if let Some(end) = rest.find(|c: char| c == ';' || c == ' ') {
                        filename = rest[..end].to_string();
                    } else {
                        filename = rest.to_string();
                    }
                }
            }
        }
        let end_off = find_slice(&body[cursor..], &end_sentinel)?;
        let part_body = body[cursor..cursor + end_off].to_vec();
        cursor += end_off + end_sentinel.len();
        if !filename.is_empty() {
            return Some(FilePart { filename, body: part_body });
        }
        if body.len() >= cursor + 2 && &body[cursor..cursor + 2] == b"--" { break; }
        if body.len() >= cursor + 2 && &body[cursor..cursor + 2] == crlf { cursor += 2; }
    }
    None
}

fn find_slice(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    if needle.is_empty() || haystack.len() < needle.len() { return None; }
    (0..=haystack.len() - needle.len()).find(|&i| haystack[i..i + needle.len()] == *needle)
}

async fn read_body_with_limit(
    tls: &mut TlsStream<TcpStream>,
    r: &Request<'_>,
    already: &[u8],
    limit: usize,
) -> Result<Vec<u8>> {
    let len: usize = r.header("Content-Length")
        .and_then(|v| v.trim().parse().ok())
        .unwrap_or(0);
    if len > limit {
        anyhow::bail!("body too large: {len} > {limit}");
    }
    // 不按 Content-Length 预分配（攻击者可声明巨大 len 触发 OOM）：
    // 起始容量封顶 1 MiB，按需增长，读到真实 len 为止。
    let mut body = Vec::with_capacity(len.min(1024 * 1024));
    body.extend_from_slice(already);
    while body.len() < len {
        let want = (len - body.len()).min(256 * 1024);
        let mut chunk = vec![0u8; want];
        let n = tls.read(&mut chunk).await?;
        if n == 0 { break; }
        body.extend_from_slice(&chunk[..n]);
    }
    body.truncate(len);
    Ok(body)
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

#[cfg(test)]
mod tests {
    use super::{sanitize_filename, path_for_log};

    #[test]
    fn sanitize_strips_path_components() {
        // 路径穿越尝试只保留最后一段，不含目录成分。
        assert_eq!(sanitize_filename("../../etc/passwd"), "passwd");
        assert_eq!(sanitize_filename("/etc/shadow"), "shadow");
        assert_eq!(sanitize_filename("..\\..\\windows\\system32\\cmd.exe"), "cmd.exe");
        assert_eq!(sanitize_filename("report.pdf"), "report.pdf");
    }

    #[test]
    fn sanitize_replaces_dot_dotdot_and_empty() {
        assert!(sanitize_filename("..").starts_with("upload-"));
        assert!(sanitize_filename(".").starts_with("upload-"));
        assert!(sanitize_filename("").starts_with("upload-"));
        assert!(sanitize_filename("/").starts_with("upload-"));
    }

    #[test]
    fn path_for_log_drops_query() {
        assert_eq!(path_for_log("/api/v1/download/x?token=secret"), "/api/v1/download/x");
        assert_eq!(path_for_log("/api/v1/version"), "/api/v1/version");
    }
}
