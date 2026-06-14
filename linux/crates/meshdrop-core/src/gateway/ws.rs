//! WebSocket：手写 101 upgrade（因为 HTTP header 已经被 http.rs 读完，
//! 不能再交给 tokio-tungstenite 自己处理握手），然后包成 WebSocketStream
//! 接收 companion-bridges §1 命令、推送 §2 事件。

use crate::gateway::http::Request;
use crate::gateway::pairing::PairingGate;
use crate::history::{HistoryItem, HistoryKind, TransferDirection, TransferStatus};
use crate::ClipboardEntry;
use crate::Device;
use crate::ShareEngine;
use anyhow::{Context, Result};
use base64::engine::general_purpose::STANDARD as BASE64_STANDARD;
use base64::Engine as _;
use futures_util::{SinkExt, StreamExt};
use log::{debug, info, warn};
use serde_json::{json, Value};
use sha1::{Digest as _, Sha1};
use std::path::PathBuf;
use std::sync::Arc;
use tokio::io::AsyncWriteExt as _;
use tokio::net::TcpStream;
use tokio_rustls::server::TlsStream;
use tokio_tungstenite::tungstenite::protocol::Role;
use tokio_tungstenite::tungstenite::Message;
use tokio_tungstenite::WebSocketStream;
use uuid::Uuid;

const WS_MAGIC: &str = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

pub async fn accept(
    mut tls: TlsStream<TcpStream>,
    req: &Request<'_>,
    engine: ShareEngine,
    gate: Arc<PairingGate>,
) -> Result<()> {
    let token = extract_token(req).unwrap_or_default();
    if !gate.is_valid_session(&token) {
        let body = b"401 Unauthorized\n";
        let resp = format!(
            "HTTP/1.1 401 Unauthorized\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
            body.len());
        tls.write_all(resp.as_bytes()).await.ok();
        tls.write_all(body).await.ok();
        anyhow::bail!("ws auth failed");
    }

    let key = req.header("Sec-WebSocket-Key")
        .context("missing Sec-WebSocket-Key")?
        .trim().to_string();
    let accept_key = compute_accept(&key);
    let resp = format!(
        "HTTP/1.1 101 Switching Protocols\r\n\
         Upgrade: websocket\r\n\
         Connection: Upgrade\r\n\
         Sec-WebSocket-Accept: {}\r\n\r\n", accept_key);
    tls.write_all(resp.as_bytes()).await.context("write 101")?;
    tls.flush().await?;
    info!("gateway WS connected");

    let mut ws = WebSocketStream::from_raw_socket(tls, Role::Server, None).await;

    let snapshot = make_state_snapshot(&engine);
    let _ = ws.send(Message::Text(snapshot.to_string())).await;

    let mut devices_rx = engine.devices_rx();
    let mut history_rx = engine.history_rx();
    let mut pp_rx = engine.pending_pairings_rx();
    let mut po_rx = engine.pending_offers_rx();
    let (out_tx, mut out_rx) = tokio::sync::mpsc::unbounded_channel::<Message>();

    let out_tx_d = out_tx.clone();
    tokio::spawn(async move {
        while devices_rx.changed().await.is_ok() {
            let v = devices_rx.borrow().clone();
            let payload = json!({
                "v": 1, "type": "device_snapshot",
                "id": format!("evt-{}", Uuid::new_v4()),
                "payload": v.iter().map(device_json).collect::<Vec<_>>()
            });
            if out_tx_d.send(Message::Text(payload.to_string())).is_err() { break; }
        }
    });
    let out_tx_h = out_tx.clone();
    tokio::spawn(async move {
        while history_rx.changed().await.is_ok() {
            let h = history_rx.borrow().clone();
            let payload = json!({
                "v": 1, "type": "history_snapshot",
                "id": format!("evt-{}", Uuid::new_v4()),
                "payload": h.iter().map(history_json).collect::<Vec<_>>()
            });
            if out_tx_h.send(Message::Text(payload.to_string())).is_err() { break; }
        }
    });
    let out_tx_p = out_tx.clone();
    tokio::spawn(async move {
        while pp_rx.changed().await.is_ok() {
            let v = pp_rx.borrow().clone();
            for p in &v {
                let payload = json!({
                    "v": 1, "type": "pairing_pending",
                    "id": format!("evt-{}", Uuid::new_v4()),
                    "payload": {
                        "id": p.id.to_string(),
                        "peerName": p.peer.name,
                        "fingerprint": p.peer.human_fingerprint(),
                    }
                });
                if out_tx_p.send(Message::Text(payload.to_string())).is_err() { return; }
            }
        }
    });
    let out_tx_o = out_tx.clone();
    tokio::spawn(async move {
        while po_rx.changed().await.is_ok() {
            let v = po_rx.borrow().clone();
            for o in &v {
                let payload = json!({
                    "v": 1, "type": "offer_pending",
                    "id": format!("evt-{}", Uuid::new_v4()),
                    "payload": {
                        "id": o.id.to_string(),
                        "peerId": o.peer.id,
                        "peerName": o.peer.name,
                        "kind": "file",
                        "files": [{"name": o.file_name, "sizeBytes": o.file_size}],
                    }
                });
                if out_tx_o.send(Message::Text(payload.to_string())).is_err() { return; }
            }
        }
    });
    // 剪贴板入站：watch 通道存的是整个 inbox（newest-first）。connect 时把 last_seen
    // 设成当前 head，避免重连重放旧条目；之后每次变更发出比 last_seen 新的条目。
    let out_tx_c = out_tx.clone();
    let mut clipboard_rx = engine.clipboard_rx();
    tokio::spawn(async move {
        let mut last_seen: Option<Uuid> = clipboard_rx.borrow().first().map(|e| e.id);
        while clipboard_rx.changed().await.is_ok() {
            let entries = clipboard_rx.borrow().clone();
            let mut fresh = Vec::new();
            for e in &entries {
                if Some(e.id) == last_seen { break; }
                fresh.push(e.clone());
            }
            if let Some(head) = entries.first() { last_seen = Some(head.id); }
            // fresh 为 newest-first，倒序发让客户端 inbox 顺序正确（旧→新）
            for e in fresh.iter().rev() {
                let payload = json!({
                    "v": 1, "type": "clipboard_received",
                    "id": format!("evt-{}", Uuid::new_v4()),
                    "payload": clipboard_json(e),
                });
                if out_tx_c.send(Message::Text(payload.to_string())).is_err() { return; }
            }
        }
    });

    loop {
        tokio::select! {
            Some(msg) = out_rx.recv() => {
                if ws.send(msg).await.is_err() { break; }
            }
            incoming = ws.next() => {
                let Some(Ok(msg)) = incoming else { break; };
                match msg {
                    Message::Text(t) => {
                        let response = handle_command(&t, &engine);
                        let _ = ws.send(Message::Text(response.to_string())).await;
                    }
                    Message::Ping(p) => { let _ = ws.send(Message::Pong(p)).await; }
                    Message::Close(_) => break,
                    _ => {}
                }
            }
            else => break,
        }
    }
    debug!("gateway WS closed");
    Ok(())
}

fn extract_token(req: &Request) -> Option<String> {
    // token 只走 Cookie / header，不接受 query string（防经 URL 泄漏 / 落日志）。
    if let Some(cookie) = req.header("Cookie") {
        for part in cookie.split(';') {
            let kv = part.trim();
            if let Some(rest) = kv.strip_prefix("meshdrop_session=") {
                return Some(rest.to_string());
            }
        }
    }
    if let Some(t) = req.header("x-meshdrop-token") {
        if !t.is_empty() { return Some(t.to_string()); }
    }
    None
}

/// 把客户端给的 fileRef 解析成一个受限的可发送路径：
/// 必须 canonicalize 成功、是普通文件，且位于 upload_dir 内；否则拒绝。
fn resolve_upload_ref(file_ref: &str) -> Option<PathBuf> {
    let upload_dir = std::fs::canonicalize(crate::gateway::http::upload_dir()).ok()?;
    let canon = std::fs::canonicalize(PathBuf::from(file_ref)).ok()?;
    if !canon.is_file() {
        return None;
    }
    if canon.starts_with(&upload_dir) {
        Some(canon)
    } else {
        None
    }
}

fn compute_accept(key: &str) -> String {
    let mut hasher = Sha1::new();
    hasher.update(key.as_bytes());
    hasher.update(WS_MAGIC.as_bytes());
    BASE64_STANDARD.encode(hasher.finalize())
}

fn handle_command(raw: &str, engine: &ShareEngine) -> Value {
    let v: Value = match serde_json::from_str(raw) {
        Ok(v) => v,
        Err(_) => return json!({"v": 1, "ok": false, "error": "invalid_json"}),
    };
    let cmd_id = v.get("id").and_then(|x| x.as_str()).unwrap_or("cmd-unknown").to_string();
    let typ = v.get("type").and_then(|x| x.as_str()).unwrap_or("");
    let payload = v.get("payload").cloned().unwrap_or(Value::Null);

    let (ok, error, result): (bool, Option<String>, Option<Value>) = match typ {
        "list_devices" => {
            let devs = engine.devices_rx().borrow().clone();
            (true, None, Some(json!(devs.iter().map(device_json).collect::<Vec<_>>())))
        }
        "get_state" => {
            let snap = make_state_snapshot(engine);
            (true, None, snap.get("payload").cloned())
        }
        "send_text" => {
            let peer_id = payload.get("peerId").and_then(|p| p.as_str()).unwrap_or("");
            let text = payload.get("text").and_then(|p| p.as_str()).unwrap_or("").to_string();
            if let Some(peer) = find_peer(engine, peer_id) {
                engine.send_text(peer, text);
                (true, None, None)
            } else {
                (false, Some("peer_not_found".into()), None)
            }
        }
        "send_clipboard" => {
            let peer_id = payload.get("peerId").and_then(|p| p.as_str()).unwrap_or("");
            let content = payload.get("content").and_then(|p| p.as_str()).unwrap_or("").to_string();
            if content.is_empty() {
                (false, Some("empty_content".into()), None)
            } else if let Some(peer) = find_peer(engine, peer_id) {
                let kind = payload.get("kind").and_then(|p| p.as_str())
                    .filter(|s| !s.is_empty())
                    .map(|s| s.to_string())
                    .unwrap_or_else(|| clip_kind(&content));
                engine.push_clipboard(peer, content, kind);
                (true, None, None)
            } else {
                (false, Some("peer_not_found".into()), None)
            }
        }
        "send_file_ref" => {
            let peer_id = payload.get("peerId").and_then(|p| p.as_str()).unwrap_or("");
            let file_ref = payload.get("fileRef").and_then(|p| p.as_str()).unwrap_or("");
            if file_ref.is_empty() {
                (false, Some("file_ref_invalid".into()), None)
            } else if let Some(peer) = find_peer(engine, peer_id) {
                // fileRef 只接受 /api/v1/upload 返回的 upload token（落在 upload_dir 内的路径）。
                // canonicalize 后校验仍在 upload_dir 下，堵任意主机文件读取（如 /etc/passwd、ssh 私钥）。
                match resolve_upload_ref(file_ref) {
                    Some(path) => {
                        engine.send_file(peer, path);
                        (true, None, None)
                    }
                    None => (false, Some("file_ref_invalid".into()), None),
                }
            } else {
                (false, Some("peer_not_found".into()), None)
            }
        }
        "accept_pairing" => respond_pairing(engine, &payload, true),
        "reject_pairing" => respond_pairing(engine, &payload, false),
        "accept_offer" => {
            match payload.get("offerId").and_then(|p| p.as_str())
                .and_then(|s| Uuid::parse_str(s).ok()) {
                Some(id) => { engine.respond_file_offer(id, true); (true, None, None) }
                None => (false, Some("bad_offer_id".into()), None),
            }
        }
        "reject_offer" => {
            match payload.get("offerId").and_then(|p| p.as_str())
                .and_then(|s| Uuid::parse_str(s).ok()) {
                Some(id) => { engine.respond_file_offer(id, false); (true, None, None) }
                None => (false, Some("bad_offer_id".into()), None),
            }
        }
        "clear_history" => { engine.clear_history(); (true, None, None) }
        "delete_history_item" => {
            match payload.get("itemId").and_then(|p| p.as_str())
                .and_then(|s| Uuid::parse_str(s).ok()) {
                Some(id) => { engine.remove_history(id); (true, None, None) }
                None => (false, Some("bad_item_id".into()), None),
            }
        }
        "cancel_transfer" => {
            match parse_history_id(&payload) {
                Some(id) if history_contains(engine, id) => {
                    engine.cancel_transfer(id);
                    (true, None, None)
                }
                Some(_) => (false, Some("history_not_found".into()), None),
                None => (false, Some("bad_item_id".into()), None),
            }
        }
        "retry_transfer" => {
            match parse_history_id(&payload) {
                Some(id) if history_contains(engine, id) => {
                    engine.retry_transfer(id);
                    (true, None, None)
                }
                Some(_) => (false, Some("history_not_found".into()), None),
                None => (false, Some("bad_item_id".into()), None),
            }
        }
        other => {
            warn!("gateway: unsupported command type {}", other);
            (false, Some("unsupported_command".into()), None)
        }
    };
    json!({
        "v": 1,
        "id": cmd_id,
        "ok": ok,
        "error": error,
        "result": result,
    })
}

fn parse_history_id(payload: &Value) -> Option<Uuid> {
    payload.get("itemId")
        .and_then(|p| p.as_str())
        .and_then(|s| Uuid::parse_str(s).ok())
}

fn history_contains(engine: &ShareEngine, id: Uuid) -> bool {
    engine.history_rx().borrow().iter().any(|h| h.id == id)
}

fn respond_pairing(engine: &ShareEngine, payload: &Value, accept: bool)
    -> (bool, Option<String>, Option<Value>)
{
    let Some(id) = payload.get("pairingId").and_then(|p| p.as_str())
        .and_then(|s| Uuid::parse_str(s).ok()) else {
        return (false, Some("bad_pairing_id".into()), None);
    };
    let trust = payload.get("trust").and_then(|t| t.as_bool()).unwrap_or(false);
    use crate::PairingDecision;
    let dec = if !accept { PairingDecision::Reject }
              else if trust { PairingDecision::Trust }
              else { PairingDecision::AllowOnce };
    engine.respond_pairing(id, dec);
    (true, None, None)
}

fn find_peer(engine: &ShareEngine, id: &str) -> Option<Device> {
    let devs = engine.devices_rx().borrow().clone();
    devs.into_iter().find(|d| d.id == id)
}

fn make_state_snapshot(engine: &ShareEngine) -> Value {
    let devs = engine.devices_rx().borrow().clone();
    let hist = engine.history_rx().borrow().clone();
    json!({
        "v": 1, "type": "state_snapshot",
        "id": format!("evt-{}", Uuid::new_v4()),
        "payload": {
            "self": {
                "id": engine.identity.id,
                "displayName": engine.display_name,
                "kind": "linux",
                "fingerprint": engine.identity.fingerprint,
            },
            "devices": devs.iter().map(device_json).collect::<Vec<_>>(),
            "history": hist.iter().map(history_json).collect::<Vec<_>>(),
        }
    })
}

fn device_json(d: &Device) -> Value {
    json!({
        "id": d.id,
        "displayName": d.name,
        "kind": d.os.as_str(),
        "model": d.model,
        "ip": d.host,
        "fingerprint": d.fingerprint,
        "online": true,
    })
}

fn clipboard_json(e: &ClipboardEntry) -> Value {
    json!({
        "id": e.id.to_string(),
        "peerName": e.peer_name,
        "kind": e.kind,
        "content": e.content,
        "ts": (e.received_at_ms / 1000) as i64,
    })
}

/// 按内容粗判剪贴板 kind（与 Apple / Android / Web / Windows 端同口径）。
fn clip_kind(content: &str) -> String {
    let t = content.trim();
    if (t.starts_with("http://") || t.starts_with("https://")) && !t.chars().any(|c| c.is_whitespace()) {
        return "link".to_string();
    }
    if t.contains('\n') && t.chars().any(|c| "{};=<>/".contains(c)) {
        return "code".to_string();
    }
    "text".to_string()
}

fn history_json(h: &HistoryItem) -> Value {
    let (kind, name, size) = match &h.kind {
        HistoryKind::Text(_) => ("text", None::<String>, 0u64),
        HistoryKind::File { name, size, .. } => ("file", Some(name.clone()), *size),
    };
    let text = match &h.kind {
        HistoryKind::Text(t) => Some(t.clone()),
        _ => None,
    };
    let status = match &h.status {
        TransferStatus::Pending => "pending",
        TransferStatus::WaitingApproval => "waiting_approval",
        TransferStatus::Transferring { .. } => "transferring",
        TransferStatus::Completed => "completed",
        TransferStatus::Failed(_) => "failed",
        TransferStatus::Canceled => "canceled",
    };
    json!({
        "id": h.id.to_string(),
        "direction": match h.direction {
            TransferDirection::Outgoing => "sent",
            TransferDirection::Incoming => "received",
        },
        "peerName": h.peer.name,
        "kind": kind,
        "text": text,
        "fileName": name,
        "sizeBytes": size,
        "status": status,
        "completedAt": h.created_at.unix_ms / 1000,
    })
}
