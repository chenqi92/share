import XCTest
@testable import MeshDropKit

final class FrameTests: XCTestCase {
    func testRoundTripText() throws {
        let body = "hello".data(using: .utf8)!
        let encoded = Frame.encode(type: MessageType.text, body: body)
        let decoded = try Frame.decode(encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.type, MessageType.text)
        XCTAssertEqual(decoded?.body, body)
        XCTAssertEqual(decoded?.consumed, 4 + 1 + body.count)
    }

    func testDecodeIncompleteHeader() throws {
        XCTAssertNil(try Frame.decode(Data([0x00, 0x00])))
    }

    func testDecodeIncompleteBody() throws {
        // length=10 但只有 4 字节 body
        let header = Data([0x00, 0x00, 0x00, 0x0A, MessageType.text])
        var payload = header
        payload.append(Data([1, 2, 3, 4]))
        XCTAssertNil(try Frame.decode(payload))
    }

    func testDecodeRejectsOversizedLength() {
        let bad = Data([0xFF, 0xFF, 0xFF, 0xFF, 0x10])  // length = 2^32 - 1
        XCTAssertThrowsError(try Frame.decode(bad))
    }

    func testFileChunkHeaderRoundTrip() {
        let uuid = UUID()
        let header = FileChunkHeader(transferID: uuid, index: 7, offset: 1_000_000)
        let data = Data([0xAA, 0xBB, 0xCC, 0xDD])
        let encoded = FileChunkHeader.encode(header, data: data)
        let decoded = FileChunkHeader.decode(encoded)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.header.transferID, uuid)
        XCTAssertEqual(decoded?.header.index, 7)
        XCTAssertEqual(decoded?.header.offset, 1_000_000)
        XCTAssertEqual(decoded?.data, data)
    }

    func testTXTRecordBase64URLRoundTrip() {
        let raw = "陈奇 的 iPhone 🚀"
        let data = raw.data(using: .utf8)!
        let encoded = TXTRecord.base64URLEncode(data)
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
        let decoded = TXTRecord.base64URLDecode(encoded)
        XCTAssertEqual(decoded, data)
        XCTAssertEqual(String(data: decoded!, encoding: .utf8), raw)
    }
}
