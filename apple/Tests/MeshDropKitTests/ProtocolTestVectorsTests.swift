import XCTest
@testable import MeshDropKit

/// 跑 `protocol/testdata/frames/*.json` 黄金向量 —— decoder 方向断言。
/// 保证 Apple 端能正确解析其它端按 spec 编出来的字节。
final class ProtocolTestVectorsTests: XCTestCase {

    private static let testdataRoot: URL = {
        // #filePath = apple/Tests/MeshDropKitTests/ProtocolTestVectorsTests.swift
        // 需到 repo 根 → 再进 protocol/testdata/frames
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()    // MeshDropKitTests/
            .deletingLastPathComponent()    // Tests/
            .deletingLastPathComponent()    // apple/
            .deletingLastPathComponent()    // repo root
            .appendingPathComponent("protocol/testdata/frames")
    }()

    // MARK: - HELLO

    func testDecodeHelloMinimalVector() throws {
        let spec = try loadSpec("hello-minimal.json")
        let frameBytes = Data(hex: spec["frame_bytes_hex"] as! String)
        let parsed = try XCTUnwrap(try Frame.decode(frameBytes))
        XCTAssertEqual(parsed.type, 0x01)
        let msg = try MessageCodec.decode(HelloMessage.self, from: parsed.body)
        XCTAssertEqual(msg.id, "0123456789abcdef0123456789abcdef")
        XCTAssertEqual(msg.name, "测试设备")
        XCTAssertEqual(msg.os, .macos)
        XCTAssertEqual(msg.fp, "00112233445566778899aabbccddeeff")
        XCTAssertEqual(msg.protocol_versions, [1])
    }

    // MARK: - TEXT

    func testDecodeTextZhEmojiVector() throws {
        let spec = try loadSpec("text-zh-emoji.json")
        let frameBytes = Data(hex: spec["frame_bytes_hex"] as! String)
        let parsed = try XCTUnwrap(try Frame.decode(frameBytes))
        XCTAssertEqual(parsed.type, 0x10)
        let msg = try MessageCodec.decode(TextMessage.self, from: parsed.body)
        XCTAssertEqual(msg.id, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(msg.content, "你好 · world 🌧️")
        XCTAssertEqual(msg.ts, 1716537600)
    }

    // MARK: - FILE_OFFER

    func testDecodeFileOfferSingleVector() throws {
        let spec = try loadSpec("file-offer-single.json")
        let frameBytes = Data(hex: spec["frame_bytes_hex"] as! String)
        let parsed = try XCTUnwrap(try Frame.decode(frameBytes))
        XCTAssertEqual(parsed.type, 0x20)
        let msg = try MessageCodec.decode(FileOfferMessage.self, from: parsed.body)
        XCTAssertEqual(msg.transfer_id, "550e8400-e29b-41d4-a716-446655440001")
        XCTAssertEqual(msg.files.count, 1)
        XCTAssertEqual(msg.files[0].index, 0)
        XCTAssertEqual(msg.files[0].name, "report.pdf")
        XCTAssertEqual(msg.files[0].size, 1_048_576)
        XCTAssertEqual(msg.files[0].sha256.count, 64)
    }

    // MARK: - FILE_CHUNK (binary)

    func testDecodeFileChunkMinVector() throws {
        let spec = try loadSpec("file-chunk-min.json")
        let frameBytes = Data(hex: spec["frame_bytes_hex"] as! String)
        let parsed = try XCTUnwrap(try Frame.decode(frameBytes))
        XCTAssertEqual(parsed.type, 0x30)
        let (header, data) = try XCTUnwrap(FileChunkHeader.decode(parsed.body))
        let expectedUUID = try XCTUnwrap(UUID(uuidString: "550E8400-E29B-41D4-A716-446655440001"))
        XCTAssertEqual(header.transferID, expectedUUID)
        XCTAssertEqual(header.index, 0)
        XCTAssertEqual(header.offset, 0)
        XCTAssertEqual(String(data: data, encoding: .utf8), "hello world")
    }

    // MARK: - HELLO_ACK

    func testDecodeHelloAckWithModelVector() throws {
        let spec = try loadSpec("hello-ack-with-model.json")
        let frameBytes = Data(hex: spec["frame_bytes_hex"] as! String)
        let parsed = try XCTUnwrap(try Frame.decode(frameBytes))
        XCTAssertEqual(parsed.type, 0x02)
        let msg = try MessageCodec.decode(HelloAckMessage.self, from: parsed.body)
        XCTAssertEqual(msg.id, "fedcba9876543210fedcba9876543210")
        XCTAssertEqual(msg.name, "iPhone 测试机")
        XCTAssertEqual(msg.os, .ios)
        XCTAssertEqual(msg.model, "iPhone17,1")
        XCTAssertEqual(msg.fp, "ffeeddccbbaa99887766554433221100")
        XCTAssertEqual(msg.selected_version, 1)
    }

    // MARK: - FILE_ACCEPT / REJECT / COMPLETE / CANCEL

    func testDecodeFileAcceptFreshVector() throws {
        let spec = try loadSpec("file-accept-fresh.json")
        let parsed = try XCTUnwrap(try Frame.decode(Data(hex: spec["frame_bytes_hex"] as! String)))
        XCTAssertEqual(parsed.type, 0x21)
        let msg = try MessageCodec.decode(FileAcceptMessage.self, from: parsed.body)
        XCTAssertEqual(msg.resume_offset, 0)
        XCTAssertEqual(msg.index, 0)
    }

    func testDecodeFileAcceptResumeVector() throws {
        let spec = try loadSpec("file-accept-resume.json")
        let parsed = try XCTUnwrap(try Frame.decode(Data(hex: spec["frame_bytes_hex"] as! String)))
        let msg = try MessageCodec.decode(FileAcceptMessage.self, from: parsed.body)
        XCTAssertEqual(msg.resume_offset, 524288)
    }

    func testDecodeFileRejectVector() throws {
        let spec = try loadSpec("file-reject-user-declined.json")
        let parsed = try XCTUnwrap(try Frame.decode(Data(hex: spec["frame_bytes_hex"] as! String)))
        XCTAssertEqual(parsed.type, 0x22)
        let msg = try MessageCodec.decode(FileRejectMessage.self, from: parsed.body)
        XCTAssertEqual(msg.reason, "user_declined")
    }

    func testDecodeFileCompleteVector() throws {
        let spec = try loadSpec("file-complete.json")
        let parsed = try XCTUnwrap(try Frame.decode(Data(hex: spec["frame_bytes_hex"] as! String)))
        XCTAssertEqual(parsed.type, 0x23)
        let msg = try MessageCodec.decode(FileCompleteMessage.self, from: parsed.body)
        XCTAssertEqual(msg.index, 0)
    }

    func testDecodeFileCancelWholeVector() throws {
        let spec = try loadSpec("file-cancel-whole.json")
        let parsed = try XCTUnwrap(try Frame.decode(Data(hex: spec["frame_bytes_hex"] as! String)))
        XCTAssertEqual(parsed.type, 0x25)
        let msg = try MessageCodec.decode(FileCancelMessage.self, from: parsed.body)
        XCTAssertNil(msg.index)
        XCTAssertEqual(msg.reason, "user_canceled")
    }

    // MARK: - PING

    func testDecodePingVector() throws {
        let spec = try loadSpec("ping.json")
        let frameBytes = Data(hex: spec["frame_bytes_hex"] as! String)
        let parsed = try XCTUnwrap(try Frame.decode(frameBytes))
        XCTAssertEqual(parsed.type, 0xF0)
        XCTAssertEqual(parsed.body, Data("{}".utf8))
    }

    // MARK: - helpers

    private func loadSpec(_ name: String) throws -> [String: Any] {
        let url = Self.testdataRoot.appendingPathComponent(name)
        let data = try Data(contentsOf: url)
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return try XCTUnwrap(obj)
    }
}

// MARK: - Data hex 辅助

private extension Data {
    init(hex: String) {
        var bytes = [UInt8]()
        bytes.reserveCapacity(hex.count / 2)
        var i = hex.startIndex
        while i < hex.endIndex {
            let next = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            if let b = UInt8(hex[i..<next], radix: 16) {
                bytes.append(b)
            }
            i = next
        }
        self.init(bytes)
    }
}
