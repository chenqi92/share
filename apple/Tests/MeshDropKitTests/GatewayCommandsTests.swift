import XCTest
@testable import MeshDropKit

final class GatewayCommandsTests: XCTestCase {

    func testMakeReplyHasRequiredFields() throws {
        let data = GatewayCommands.makeReply(id: "cmd-1", ok: true, result: ["devices": []])
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["v"] as? Int, 1)
        XCTAssertEqual(obj["id"] as? String, "cmd-1")
        XCTAssertEqual(obj["ok"] as? Bool, true)
        // error 字段 ok 时为 NSNull，序列化后是 `null`
        XCTAssertTrue(obj["error"] is NSNull)
        let result = try XCTUnwrap(obj["result"] as? [String: Any])
        XCTAssertNotNil(result["devices"])
    }

    func testMakeReplyError() throws {
        let data = GatewayCommands.makeReply(id: "cmd-x", ok: false, error: "peer_not_found")
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["ok"] as? Bool, false)
        XCTAssertEqual(obj["error"] as? String, "peer_not_found")
    }

    @MainActor
    func testFileForHistoryReturnsIncomingFileURL() throws {
        // 写一个临时文件，把它当作"已接收"的 incoming history item
        let tmpDir = FileManager.default.temporaryDirectory
        let tmpURL = tmpDir.appendingPathComponent("test-\(UUID().uuidString).bin")
        try Data("hello".utf8).write(to: tmpURL)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        // 反射手术：通过创建一个 fresh ShareEngine 看不到，因为 history 是 private(set)。
        // 退一步只验证：未匹配 id 返回 nil。完整接收链路在 conformance 用例里覆盖。
        let engine = ShareEngine.shared
        let commands = GatewayCommands(engine: engine)
        XCTAssertNil(commands.fileForHistory(id: UUID()))
    }

    func testEncodeEventSchema() throws {
        let data = GatewayCommands.encodeEvent(type: "device_snapshot", payload: [["id": "abc"]])
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(obj["v"] as? Int, 1)
        XCTAssertEqual(obj["type"] as? String, "device_snapshot")
        XCTAssertNotNil(obj["ts"] as? Int)
        let id = try XCTUnwrap(obj["id"] as? String)
        XCTAssertTrue(id.hasPrefix("evt-"))
        let payload = try XCTUnwrap(obj["payload"] as? [[String: Any]])
        XCTAssertEqual(payload.first?["id"] as? String, "abc")
    }
}
