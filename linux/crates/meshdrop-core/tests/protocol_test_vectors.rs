//! 跑 `protocol/testdata/frames/*.json` 黄金向量 —— decoder 方向断言。
//! 保证 Linux 端能正确解析其它端按 spec 编出来的字节。

use meshdrop_core::protocol::*;
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

fn testdata_root() -> PathBuf {
    // CARGO_MANIFEST_DIR = linux/crates/meshdrop-core/
    // 上溯到 repo 根，进 protocol/testdata/frames
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent().unwrap()          // crates/
        .parent().unwrap()          // linux/
        .parent().unwrap()          // repo root
        .join("protocol/testdata/frames")
}

fn load_spec(name: &str) -> Value {
    let path = testdata_root().join(name);
    let s = fs::read_to_string(&path)
        .unwrap_or_else(|e| panic!("read {}: {}", path.display(), e));
    serde_json::from_str(&s).unwrap()
}

fn from_hex(hex: &str) -> Vec<u8> {
    (0..hex.len()).step_by(2)
        .map(|i| u8::from_str_radix(&hex[i..i + 2], 16).unwrap())
        .collect()
}

fn decoded(buf: &[u8]) -> (u8, &[u8]) {
    match decode_frame(buf).expect("decode") {
        DecodeResult::Decoded { msg_type, body, .. } => (msg_type, body),
        DecodeResult::NeedMore => panic!("incomplete frame"),
    }
}

#[test]
fn hello_minimal_vector_decodes() {
    let spec = load_spec("hello-minimal.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::HELLO);
    let msg: HelloMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.id, "0123456789abcdef0123456789abcdef");
    assert_eq!(msg.name, "测试设备");
    assert_eq!(msg.os, "macos");
    assert_eq!(msg.fp, "00112233445566778899aabbccddeeff");
    assert_eq!(msg.protocol_versions, vec![1]);
}

#[test]
fn text_zh_emoji_vector_decodes() {
    let spec = load_spec("text-zh-emoji.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::TEXT);
    let msg: TextMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.id, "550e8400-e29b-41d4-a716-446655440000");
    assert_eq!(msg.content, "你好 · world 🌧️");
    assert_eq!(msg.ts, 1716537600);
}

#[test]
fn file_offer_single_vector_decodes() {
    let spec = load_spec("file-offer-single.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::FILE_OFFER);
    let msg: FileOfferMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.transfer_id, "550e8400-e29b-41d4-a716-446655440001");
    assert_eq!(msg.files.len(), 1);
    assert_eq!(msg.files[0].index, 0);
    assert_eq!(msg.files[0].name, "report.pdf");
    assert_eq!(msg.files[0].size, 1_048_576);
    assert_eq!(msg.files[0].sha256.len(), 64);
}

#[test]
fn file_chunk_min_vector_decodes() {
    let spec = load_spec("file-chunk-min.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::FILE_CHUNK);
    let (header, data) = decode_file_chunk(body).unwrap();
    assert_eq!(header.transfer_id.to_string(), "550e8400-e29b-41d4-a716-446655440001");
    assert_eq!(header.index, 0);
    assert_eq!(header.offset, 0);
    assert_eq!(data, b"hello world");
}

#[test]
fn hello_ack_with_model_vector_decodes() {
    let spec = load_spec("hello-ack-with-model.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::HELLO_ACK);
    let msg: HelloAckMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.id, "fedcba9876543210fedcba9876543210");
    assert_eq!(msg.name, "iPhone 测试机");
    assert_eq!(msg.os, "ios");
    assert_eq!(msg.model.as_deref(), Some("iPhone17,1"));
    assert_eq!(msg.selected_version, 1);
}

#[test]
fn file_accept_fresh_vector_decodes() {
    let spec = load_spec("file-accept-fresh.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::FILE_ACCEPT);
    let msg: FileAcceptMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.resume_offset, 0);
    assert_eq!(msg.index, 0);
}

#[test]
fn file_accept_resume_vector_decodes() {
    let spec = load_spec("file-accept-resume.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (_, body) = decoded(&bytes);
    let msg: FileAcceptMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.resume_offset, 524288);
}

#[test]
fn file_reject_vector_decodes() {
    let spec = load_spec("file-reject-user-declined.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::FILE_REJECT);
    let msg: FileRejectMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.reason, "user_declined");
}

#[test]
fn file_complete_vector_decodes() {
    let spec = load_spec("file-complete.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::FILE_COMPLETE);
    let msg: FileCompleteMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.index, 0);
}

#[test]
fn file_cancel_whole_vector_decodes() {
    let spec = load_spec("file-cancel-whole.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::FILE_CANCEL);
    // Linux 端 FileCancelMessage 没有定义；用 Value 解析校验字段
    let v: serde_json::Value = serde_json::from_slice(body).unwrap();
    assert!(v["index"].is_null());
    assert_eq!(v["reason"], "user_canceled");
}

#[test]
fn ping_vector_decodes() {
    let spec = load_spec("ping.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::PING);
    assert_eq!(body, b"{}");
}
