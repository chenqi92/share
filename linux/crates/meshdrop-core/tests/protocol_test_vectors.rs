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
    let msg: FileCancelMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.transfer_id, "550e8400-e29b-41d4-a716-446655440001");
    assert!(msg.index.is_none());
    assert_eq!(msg.reason, "user_canceled");
}

#[test]
fn ping_vector_decodes() {
    let spec = load_spec("ping.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (ty, body) = decoded(&bytes);
    assert_eq!(ty, msg_type::PING);
    assert_eq!(body, b"{}");
}

// ─── encode 回环 / 边界 / 负例（补 decode-only 之外的回归保护） ──────────

#[test]
fn encode_decode_roundtrip() {
    // 任意 msg_type + body 编码后应能解回同样的 type/body，且 consumed 覆盖整帧。
    for (ty, body) in [
        (msg_type::TEXT, b"hello".as_slice()),
        (msg_type::CLIPBOARD, b"{\"k\":\"v\"}".as_slice()),
        (msg_type::HELLO, b"".as_slice()), // 空 body：length=1（仅 type 字节）
        (msg_type::PONG, b"{}".as_slice()),
    ] {
        let frame = encode_frame(ty, body);
        match decode_frame(&frame).expect("decode") {
            DecodeResult::Decoded { msg_type: dty, body: dbody, consumed } => {
                assert_eq!(dty, ty);
                assert_eq!(dbody, body);
                assert_eq!(consumed, frame.len());
            }
            DecodeResult::NeedMore => panic!("roundtrip should decode fully"),
        }
    }
}

#[test]
fn decode_need_more_on_short_header_and_body() {
    // 不足 4 字节的长度前缀 → NeedMore
    assert!(matches!(decode_frame(&[0x00, 0x00, 0x05]), Ok(DecodeResult::NeedMore)));
    // 长度声明 5，但 body 不足 → NeedMore
    let mut buf = 5u32.to_be_bytes().to_vec();
    buf.push(msg_type::TEXT); // 只有 type，还差 4 字节
    assert!(matches!(decode_frame(&buf), Ok(DecodeResult::NeedMore)));
}

#[test]
fn decode_rejects_zero_and_oversized_length() {
    // length=0 非法（至少要含 1 字节 msg_type）
    let zero = 0u32.to_be_bytes().to_vec();
    assert!(decode_frame(&zero).is_err());
    // length 超过 MAX_FRAME_LENGTH 非法
    let too_big = ((MAX_FRAME_LENGTH as u32) + 1).to_be_bytes().to_vec();
    assert!(decode_frame(&too_big).is_err());
}

#[test]
fn decode_leaves_trailing_bytes_for_next_frame() {
    // 一个完整帧后面跟着下一帧的部分字节：consumed 应只覆盖第一帧。
    let first = encode_frame(msg_type::TEXT, b"a");
    let mut buf = first.clone();
    buf.extend_from_slice(&[0x00, 0x00]); // 下一帧的不完整前缀
    match decode_frame(&buf).expect("decode") {
        DecodeResult::Decoded { consumed, .. } => assert_eq!(consumed, first.len()),
        DecodeResult::NeedMore => panic!("first frame is complete"),
    }
}

#[test]
fn clipboard_0x11_roundtrip() {
    // 0x11 CLIPBOARD：编码 ClipboardMessage 后解回字段一致。
    let msg = ClipboardMessage {
        id: "11111111-1111-1111-1111-111111111111".into(),
        content: "https://example.com".into(),
        kind: "link".into(),
        ts: 1_700_000_000,
    };
    let body = serde_json::to_vec(&msg).unwrap();
    let frame = encode_frame(msg_type::CLIPBOARD, &body);
    let (ty, dbody) = decoded(&frame);
    assert_eq!(ty, msg_type::CLIPBOARD);
    let back: ClipboardMessage = serde_json::from_slice(dbody).unwrap();
    assert_eq!(back.content, "https://example.com");
    assert_eq!(back.kind, "link");
    assert_eq!(back.ts, 1_700_000_000);
}

#[test]
fn hello_fp_is_32_lowercase_hex() {
    // HELLO.fp 必须是 32 位小写 hex（SHA-256 公钥前 16 字节）。
    let spec = load_spec("hello-minimal.json");
    let bytes = from_hex(spec["frame_bytes_hex"].as_str().unwrap());
    let (_, body) = decoded(&bytes);
    let msg: HelloMessage = serde_json::from_slice(body).unwrap();
    assert_eq!(msg.fp.len(), 32);
    assert!(msg.fp.bytes().all(|b| matches!(b, b'0'..=b'9' | b'a'..=b'f')));
}

#[test]
fn file_chunk_header_too_short_returns_none() {
    // body 短于 FILE_CHUNK 头部（28 字节）→ decode_file_chunk 返回 None。
    let short = vec![0u8; FILE_CHUNK_HEADER_SIZE - 1];
    assert!(decode_file_chunk(&short).is_none());
}
