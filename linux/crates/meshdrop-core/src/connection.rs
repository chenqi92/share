//! 在双向认证的 TLS 连接上按帧异步读写。

use crate::protocol::{decode_frame, encode_frame, DecodeResult, FrameError};
use crate::{identity::Identity, transport_security};
use anyhow::Result;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::Notify;
use tokio::sync::{mpsc, oneshot};

/// 外部对 Connection 触发的事件。
#[derive(Debug)]
pub enum ConnEvent {
    Ready { fingerprint: String },
    Frame { msg_type: u8, body: Vec<u8> },
    Closed(Option<String>), // 关闭原因（错误描述或 None=对端正常关闭）
}

struct Outbound {
    msg_type: u8,
    body: Vec<u8>,
    flushed: Option<oneshot::Sender<()>>,
}

#[derive(Clone)]
pub struct Connection {
    pub remote: String,
    pub events_rx: async_channel::Receiver<ConnEvent>,
    out_tx: mpsc::UnboundedSender<Outbound>,
    closer: Arc<Notify>,
}

impl Connection {
    /// 出方：连接 `host:port`。立即返回，事件通过 `events_rx`。
    pub fn connect(host: String, port: u16, identity: Arc<Identity>, expected: String) -> Self {
        let (events_tx, events_rx) = async_channel::unbounded();
        let (out_tx, out_rx) = mpsc::unbounded_channel();
        let closer = Arc::new(Notify::new());
        let remote = format!("{}:{}", host, port);

        let closer_c = closer.clone();
        tokio::spawn(async move {
            let setup = async {
                let tcp = TcpStream::connect((host.as_str(), port)).await?;
                transport_security::handshake(tcp, &identity, Some(expected)).await
            };
            run_loop(setup, events_tx, out_rx, closer_c).await;
        });

        Self {
            remote,
            events_rx,
            out_tx,
            closer,
        }
    }

    /// 入方：用已建立的 TcpStream 构造。
    pub fn from_stream(stream: TcpStream, peer_addr: SocketAddr, identity: Arc<Identity>) -> Self {
        let (events_tx, events_rx) = async_channel::unbounded();
        let (out_tx, out_rx) = mpsc::unbounded_channel();
        let closer = Arc::new(Notify::new());
        let closer_c = closer.clone();
        let remote = peer_addr.to_string();

        tokio::spawn(async move {
            run_loop(
                transport_security::handshake(stream, &identity, None),
                events_tx,
                out_rx,
                closer_c,
            )
            .await;
        });

        Self {
            remote,
            events_rx,
            out_tx,
            closer,
        }
    }

    /// 发送一帧。错误只在 Connection 已关闭时返回。
    pub fn send(&self, msg_type: u8, body: Vec<u8>) -> Result<()> {
        self.out_tx
            .send(Outbound {
                msg_type,
                body,
                flushed: None,
            })
            .map_err(|_| anyhow::anyhow!("connection closed"))
    }

    /// Wait for a terminal frame to leave TLS before closing the socket.
    pub(crate) async fn send_and_flush(&self, msg_type: u8, body: Vec<u8>) -> Result<()> {
        let (tx, rx) = oneshot::channel();
        self.out_tx
            .send(Outbound {
                msg_type,
                body,
                flushed: Some(tx),
            })
            .map_err(|_| anyhow::anyhow!("connection closed"))?;
        tokio::time::timeout(std::time::Duration::from_secs(5), rx).await??;
        Ok(())
    }

    pub fn close(&self) {
        self.closer.notify_one();
    }
}

async fn run_loop(
    setup: impl std::future::Future<Output = Result<(tokio_rustls::TlsStream<TcpStream>, String)>>,
    events_tx: async_channel::Sender<ConnEvent>,
    mut out_rx: mpsc::UnboundedReceiver<Outbound>,
    closer: Arc<Notify>,
) {
    let result = tokio::select! {
        _ = closer.notified() => return,
        result = tokio::time::timeout(std::time::Duration::from_secs(15), setup) => result,
    };
    let (mut stream, fingerprint) =
        match result.map_err(anyhow::Error::from).and_then(|setup| setup) {
            Ok(authenticated) => authenticated,
            Err(error) => {
                let _ = events_tx
                    .send(ConnEvent::Closed(Some(error.to_string())))
                    .await;
                return;
            }
        };
    let _ = events_tx.send(ConnEvent::Ready { fingerprint }).await;

    let mut buf = vec![0u8; 64 * 1024];
    let mut pending: Vec<u8> = Vec::with_capacity(64 * 1024);

    loop {
        tokio::select! {
            biased;
            _ = closer.notified() => break,
            send_req = out_rx.recv() => {
                match send_req {
                    Some(frame) => {
                        let bytes = encode_frame(frame.msg_type, &frame.body);
                        let send = async { stream.write_all(&bytes).await?; stream.flush().await };
                        if let Err(e) = send.await {
                            let _ = events_tx.send(ConnEvent::Closed(Some(e.to_string()))).await;
                            return;
                        }
                        if let Some(flushed) = frame.flushed { let _ = flushed.send(()); }
                    }
                    None => break,
                }
            },
            read_res = stream.read(&mut buf) => {
                match read_res {
                    Ok(0) => {
                        let _ = events_tx.send(ConnEvent::Closed(None)).await;
                        return;
                    }
                    Ok(n) => {
                        pending.extend_from_slice(&buf[..n]);
                        // 解出所有可用 frame
                        loop {
                            match decode_frame(&pending) {
                                Ok(DecodeResult::NeedMore) => break,
                                Ok(DecodeResult::Decoded { msg_type, body, consumed }) => {
                                    let body_vec = body.to_vec();
                                    pending.drain(..consumed);
                                    if events_tx.send(ConnEvent::Frame { msg_type, body: body_vec }).await.is_err() {
                                        return;
                                    }
                                }
                                Err(FrameError::LengthOutOfRange(len)) => {
                                    let _ = events_tx.send(ConnEvent::Closed(Some(format!("length OOR: {}", len)))).await;
                                    return;
                                }
                            }
                        }
                    }
                    Err(e) => {
                        let _ = events_tx.send(ConnEvent::Closed(Some(e.to_string()))).await;
                        return;
                    }
                }
            }
        }
    }

    let _ = stream.shutdown().await;
    let _ = events_tx.send(ConnEvent::Closed(None)).await;
}
