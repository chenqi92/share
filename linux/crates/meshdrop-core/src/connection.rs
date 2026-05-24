//! tokio TCP 包装：按帧 (Frame) 异步读写。
//!
//! 一次 [Connection::start] 会启动后台读循环；通过 mpsc::UnboundedSender<Outbound>
//! 串行化写。close 后所有未发完的 Outbound 都会被丢弃。

use crate::protocol::{decode_frame, encode_frame, DecodeResult, FrameError};
use anyhow::Result;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio::sync::Notify;

/// 外部对 Connection 触发的事件。
#[derive(Debug)]
pub enum ConnEvent {
    Ready,
    Frame { msg_type: u8, body: Vec<u8> },
    Closed(Option<String>),    // 关闭原因（错误描述或 None=对端正常关闭）
}

#[derive(Clone)]
pub struct Connection {
    pub remote: String,
    pub events_rx: async_channel::Receiver<ConnEvent>,
    out_tx: mpsc::UnboundedSender<(u8, Vec<u8>)>,
    closer: Arc<Notify>,
}

impl Connection {
    /// 出方：连接 `host:port`。立即返回，事件通过 `events_rx`。
    pub fn connect(host: String, port: u16) -> Self {
        let (events_tx, events_rx) = async_channel::unbounded();
        let (out_tx, out_rx) = mpsc::unbounded_channel();
        let closer = Arc::new(Notify::new());
        let remote = format!("{}:{}", host, port);

        let closer_c = closer.clone();
        let remote_c = remote.clone();
        tokio::spawn(async move {
            match TcpStream::connect(&remote_c).await {
                Ok(stream) => run_loop(stream, events_tx, out_rx, closer_c).await,
                Err(e) => { let _ = events_tx.send(ConnEvent::Closed(Some(e.to_string()))).await; }
            }
        });

        Self { remote, events_rx, out_tx, closer }
    }

    /// 入方：用已建立的 TcpStream 构造。
    pub fn from_stream(stream: TcpStream, peer_addr: SocketAddr) -> Self {
        let (events_tx, events_rx) = async_channel::unbounded();
        let (out_tx, out_rx) = mpsc::unbounded_channel();
        let closer = Arc::new(Notify::new());
        let closer_c = closer.clone();
        let remote = peer_addr.to_string();

        tokio::spawn(async move {
            run_loop(stream, events_tx, out_rx, closer_c).await;
        });

        Self { remote, events_rx, out_tx, closer }
    }

    /// 发送一帧。错误只在 Connection 已关闭时返回。
    pub fn send(&self, msg_type: u8, body: Vec<u8>) -> Result<()> {
        self.out_tx.send((msg_type, body))
            .map_err(|_| anyhow::anyhow!("connection closed"))
    }

    pub fn close(&self) {
        self.closer.notify_waiters();
    }
}

async fn run_loop(
    mut stream: TcpStream,
    events_tx: async_channel::Sender<ConnEvent>,
    mut out_rx: mpsc::UnboundedReceiver<(u8, Vec<u8>)>,
    closer: Arc<Notify>,
) {
    let _ = events_tx.send(ConnEvent::Ready).await;

    let mut buf = vec![0u8; 64 * 1024];
    let mut pending: Vec<u8> = Vec::with_capacity(64 * 1024);

    loop {
        tokio::select! {
            biased;
            _ = closer.notified() => break,
            send_req = out_rx.recv() => {
                match send_req {
                    Some((t, body)) => {
                        let frame = encode_frame(t, &body);
                        if let Err(e) = stream.write_all(&frame).await {
                            let _ = events_tx.send(ConnEvent::Closed(Some(e.to_string()))).await;
                            return;
                        }
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

    let _ = events_tx.send(ConnEvent::Closed(None)).await;
}
