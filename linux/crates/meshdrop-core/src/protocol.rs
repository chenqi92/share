//! 协议规范的 Rust 实现：Frame 编解码 + 消息类型 + JSON 消息 + FILE_CHUNK 二进制头。

use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub const MAX_FRAME_LENGTH: usize = 16 * 1024 * 1024;

// ─── Frame ─────────────────────────────────────────────────────────────

#[derive(Debug, thiserror::Error)]
pub enum FrameError {
    #[error("length out of range: {0}")]
    LengthOutOfRange(u32),
}

pub fn encode_frame(msg_type: u8, body: &[u8]) -> Vec<u8> {
    let length = body.len() + 1;
    assert!(length <= MAX_FRAME_LENGTH);
    let mut out = Vec::with_capacity(4 + length);
    out.extend_from_slice(&(length as u32).to_be_bytes());
    out.push(msg_type);
    out.extend_from_slice(body);
    out
}

pub enum DecodeResult<'a> {
    NeedMore,
    Decoded { msg_type: u8, body: &'a [u8], consumed: usize },
}

pub fn decode_frame(buf: &[u8]) -> Result<DecodeResult<'_>, FrameError> {
    if buf.len() < 4 {
        return Ok(DecodeResult::NeedMore);
    }
    let length = u32::from_be_bytes([buf[0], buf[1], buf[2], buf[3]]);
    if !(1..=MAX_FRAME_LENGTH as u32).contains(&length) {
        return Err(FrameError::LengthOutOfRange(length));
    }
    let total = 4 + length as usize;
    if buf.len() < total {
        return Ok(DecodeResult::NeedMore);
    }
    let msg_type = buf[4];
    let body = &buf[5..total];
    Ok(DecodeResult::Decoded { msg_type, body, consumed: total })
}

// ─── 消息类型常量 ─────────────────────────────────────────────────────

pub mod msg_type {
    pub const HELLO: u8         = 0x01;
    pub const HELLO_ACK: u8     = 0x02;
    pub const TEXT: u8          = 0x10;
    pub const CLIPBOARD: u8     = 0x11;
    pub const FILE_OFFER: u8    = 0x20;
    pub const FILE_ACCEPT: u8   = 0x21;
    pub const FILE_REJECT: u8   = 0x22;
    pub const FILE_COMPLETE: u8 = 0x23;
    pub const FILE_CANCEL: u8   = 0x25;
    pub const FILE_CHUNK: u8    = 0x30;
    pub const PING: u8          = 0xF0;
    pub const PONG: u8          = 0xF1;
}

// ─── JSON 消息 ───────────────────────────────────────────────────────

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HelloMessage {
    pub id: String,
    pub name: String,
    pub os: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
    pub fp: String,
    pub protocol_versions: Vec<u8>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct HelloAckMessage {
    pub id: String,
    pub name: String,
    pub os: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub model: Option<String>,
    pub fp: String,
    pub protocol_versions: Vec<u8>,
    pub selected_version: u8,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct TextMessage {
    pub id: String,
    pub content: String,
    pub ts: i64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct ClipboardMessage {
    pub id: String,
    pub content: String,
    pub kind: String,    // text | link | code
    pub ts: i64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileMeta {
    pub index: i32,
    pub name: String,
    pub size: u64,
    pub sha256: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileOfferMessage {
    pub transfer_id: String,
    pub files: Vec<FileMeta>,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileAcceptMessage {
    pub transfer_id: String,
    pub index: i32,
    pub resume_offset: u64,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileRejectMessage {
    pub transfer_id: String,
    pub index: i32,
    pub reason: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileCompleteMessage {
    pub transfer_id: String,
    pub index: i32,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileCancelMessage {
    pub transfer_id: String,
    /// None 表示整个 transfer 取消；Some(i) 表示仅取消该 file index。
    pub index: Option<i32>,
    pub reason: String,
}

// ─── FILE_CHUNK 二进制头部 ────────────────────────────────────────────

pub struct FileChunkHeader {
    pub transfer_id: Uuid,
    pub index: u32,
    pub offset: u64,
}

pub const FILE_CHUNK_HEADER_SIZE: usize = 16 + 4 + 8;

pub fn encode_file_chunk(header: &FileChunkHeader, data: &[u8]) -> Vec<u8> {
    let mut out = Vec::with_capacity(FILE_CHUNK_HEADER_SIZE + data.len());
    out.extend_from_slice(header.transfer_id.as_bytes());      // 16 bytes BE
    out.extend_from_slice(&header.index.to_be_bytes());        // 4 bytes
    out.extend_from_slice(&header.offset.to_be_bytes());       // 8 bytes
    out.extend_from_slice(data);
    out
}

pub fn decode_file_chunk(body: &[u8]) -> Option<(FileChunkHeader, &[u8])> {
    if body.len() < FILE_CHUNK_HEADER_SIZE { return None; }
    let mut id_bytes = [0u8; 16];
    id_bytes.copy_from_slice(&body[0..16]);
    let transfer_id = Uuid::from_bytes(id_bytes);
    let index = u32::from_be_bytes([body[16], body[17], body[18], body[19]]);
    let offset = u64::from_be_bytes([
        body[20], body[21], body[22], body[23],
        body[24], body[25], body[26], body[27],
    ]);
    Some((FileChunkHeader { transfer_id, index, offset }, &body[FILE_CHUNK_HEADER_SIZE..]))
}
