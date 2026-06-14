//! Web Gateway：让浏览器通过 LAN 上的 native client 收发消息。
//! 监听 `0.0.0.0:<port>`（默认 7384，可配置），全程 TLS（自签）。
//! 实现见 `protocol/companion-bridges.md §4.3`。

pub mod cert;
pub mod http;
pub mod pairing;
pub mod ws;

use crate::ShareEngine;
use anyhow::{Context, Result};
use log::{debug, info, warn};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::task::JoinHandle;
use tokio_rustls::rustls::ServerConfig;
use tokio_rustls::TlsAcceptor;

pub const DEFAULT_PORT: u16 = 7384;

pub struct GatewayHandle {
    pub port: u16,
    pub pairing: Arc<pairing::PairingGate>,
    pub cert_dir: PathBuf,
    _task: JoinHandle<()>,
}

impl GatewayHandle {
    pub fn pairing_code(&self) -> String {
        self.pairing.current_code()
    }
}

/// 启动 Web Gateway。返回时已绑定 `port`；如果绑定失败回报错。
pub async fn start(engine: ShareEngine, port: u16) -> Result<GatewayHandle> {
    let _ = rustls::crypto::aws_lc_rs::default_provider().install_default();

    let cert_dir = config_dir()?;
    let bundle = cert::load_or_generate(&cert_dir).context("gateway cert")?;

    // 浏览器面向的自签 Gateway 强制 TLS 1.3 ONLY（与 protocol/README TLS1.3 口径统一），
    // 并把 cipher suite 收敛到 TLS 1.3 AEAD 白名单，杜绝向 TLS 1.2 / 弱套件降级。
    let provider = tls13_only_provider();
    let mut server_config = ServerConfig::builder_with_provider(Arc::new(provider))
        .with_protocol_versions(&[&tokio_rustls::rustls::version::TLS13])
        .context("rustls TLS1.3-only versions")?
        .with_no_client_auth()
        .with_single_cert(bundle.cert_chain, bundle.key)
        .context("rustls ServerConfig")?;
    server_config.alpn_protocols = vec![b"http/1.1".to_vec()];
    let acceptor = TlsAcceptor::from(Arc::new(server_config));

    let listener = TcpListener::bind(("0.0.0.0", port)).await
        .with_context(|| format!("bind gateway 0.0.0.0:{}", port))?;
    let actual_port = listener.local_addr()?.port();
    info!("Web Gateway listening on https://0.0.0.0:{}", actual_port);

    let gate = Arc::new(pairing::PairingGate::new());
    // 配对码是会话凭据，不写进常驻 info 日志（避免落盘泄漏）；UI 从 GatewayHandle 取。
    debug!("Web Gateway pairing code generated");

    let gate_run = gate.clone();
    let task = tokio::spawn(async move {
        loop {
            let (sock, addr) = match listener.accept().await {
                Ok(x) => x,
                Err(e) => { warn!("gateway accept: {}", e); break; }
            };
            let acceptor = acceptor.clone();
            let engine = engine.clone();
            let gate = gate_run.clone();
            tokio::spawn(async move {
                let tls = match acceptor.accept(sock).await {
                    Ok(t) => t,
                    Err(e) => { warn!("gateway TLS from {}: {}", addr, e); return; }
                };
                if let Err(e) = http::handle(tls, engine, gate).await {
                    warn!("gateway request from {}: {}", addr, e);
                }
            });
        }
    });

    Ok(GatewayHandle {
        port: actual_port,
        pairing: gate,
        cert_dir,
        _task: task,
    })
}

fn config_dir() -> Result<PathBuf> {
    let base = dirs::config_dir().context("no XDG config dir")?;
    let dir = base.join("meshdrop");
    std::fs::create_dir_all(&dir).context("create config dir")?;
    Ok(dir)
}

/// 在 aws-lc-rs provider 基础上把 cipher suite 收敛到 TLS 1.3 AEAD 白名单
/// （TLS_AES_256_GCM / TLS_AES_128_GCM / TLS_CHACHA20_POLY1305），剔除其余套件。
fn tls13_only_provider() -> tokio_rustls::rustls::crypto::CryptoProvider {
    use tokio_rustls::rustls::crypto::aws_lc_rs;
    let allowed = [
        aws_lc_rs::cipher_suite::TLS13_AES_256_GCM_SHA384,
        aws_lc_rs::cipher_suite::TLS13_AES_128_GCM_SHA256,
        aws_lc_rs::cipher_suite::TLS13_CHACHA20_POLY1305_SHA256,
    ];
    let base = aws_lc_rs::default_provider();
    tokio_rustls::rustls::crypto::CryptoProvider {
        cipher_suites: base
            .cipher_suites
            .into_iter()
            .filter(|cs| allowed.contains(cs))
            .collect(),
        ..base
    }
}
