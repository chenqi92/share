import XCTest
@testable import MeshDropKit

final class WebSocketFrameTests: XCTestCase {

    // RFC 6455 §1.3：key "dGhlIHNhbXBsZSBub25jZQ==" → accept "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
    func testComputeAcceptStandardVector() {
        let acc = WebSocketFrame.computeAccept(key: "dGhlIHNhbXBsZSBub25jZQ==")
        XCTAssertEqual(acc, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    }

    func testEncodeShortText() {
        let data = WebSocketFrame.text("hello")
        // 0x81 = FIN + text, 0x05 = len 5, then "hello"
        XCTAssertEqual(data.first, 0x81)
        XCTAssertEqual(data[1], 0x05)
        XCTAssertEqual(data.suffix(5), Data("hello".utf8))
    }

    func testEncodeMediumLengthText() {
        let payload = String(repeating: "x", count: 200)
        let data = WebSocketFrame.text(payload)
        XCTAssertEqual(data.first, 0x81)
        XCTAssertEqual(data[1], 126)        // extended length flag
        let extLen = (UInt16(data[2]) << 8) | UInt16(data[3])
        XCTAssertEqual(extLen, 200)
    }

    func testEncodeLongLengthText() {
        let payload = String(repeating: "x", count: 70_000)
        let data = WebSocketFrame.text(payload)
        XCTAssertEqual(data.first, 0x81)
        XCTAssertEqual(data[1], 127)
        // 后 8 字节是大端 length
        var lenBE: UInt64 = 0
        for i in 0..<8 { lenBE = (lenBE << 8) | UInt64(data[2 + i]) }
        XCTAssertEqual(lenBE, 70_000)
    }

    func testDecodeMaskedText() {
        // 构造一个 masked client-frame 表示 "abc"
        let payload: [UInt8] = [0x61, 0x62, 0x63]
        let mask: [UInt8] = [0x37, 0xfa, 0x21, 0x3d]
        let masked: [UInt8] = payload.enumerated().map { (i, b) in b ^ mask[i % 4] }
        var frame = Data([0x81, 0x83]) // FIN + text, masked + len 3
        frame.append(contentsOf: mask)
        frame.append(contentsOf: masked)

        switch WebSocketFrame.decode(buffer: frame) {
        case .frame(let d, let consumed):
            XCTAssertEqual(d.opcode, .text)
            XCTAssertEqual(d.payload, Data("abc".utf8))
            XCTAssertTrue(d.isFinal)
            XCTAssertEqual(consumed, frame.count)
        default:
            XCTFail("expected complete frame")
        }
    }

    func testDecodeRejectsUnmaskedClientFrame() {
        let frame = Data([0x81, 0x03, 0x61, 0x62, 0x63])
        switch WebSocketFrame.decode(buffer: frame) {
        case .error: break
        default: XCTFail("expected error for unmasked client frame")
        }
    }

    func testDecodeNeedsMoreOnPartial() {
        let frame = Data([0x81])
        switch WebSocketFrame.decode(buffer: frame) {
        case .needsMore: break
        default: XCTFail("expected needsMore")
        }
    }

    func testCloseFrameEncoded() {
        let f = WebSocketFrame.close(code: 1000)
        XCTAssertEqual(f[0], 0x88)            // FIN + close opcode
        XCTAssertEqual(f[1], 0x02)            // 2 字节 payload
        let code = (UInt16(f[2]) << 8) | UInt16(f[3])
        XCTAssertEqual(code, 1000)
    }
}
