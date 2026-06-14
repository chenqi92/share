import XCTest
@testable import MeshDropKit

/// 校验 Watch Companion Bridge 的 wire schema 与 protocol/companion-bridges.md 一致：
/// 事件 payload FLAT、id 字段名统一为 `id`、DTO 含 ip/busy/code/files[]。
final class WatchBridgeWireTests: XCTestCase {

    private func encodeEvent(_ event: WatchBridge.Event) throws -> [String: Any] {
        try WatchBridge.encode(event)
    }

    func testDeviceAddedPayloadIsFlat() throws {
        let dto = WatchBridge.DeviceDTO(
            id: "dev-1", displayName: "李莉", kind: "mac",
            model: "MacBook Pro", ip: "192.168.1.5", rttMs: 12,
            online: true, trusted: true, busy: false
        )
        let event = WatchBridge.Event(type: .deviceAdded, payload: .init(device: dto))
        let dict = try encodeEvent(event)
        let payload = try XCTUnwrap(dict["payload"] as? [String: Any])
        // FLAT：payload 直接是 Device 字段，没有 "device" 子键
        XCTAssertNil(payload["device"])
        XCTAssertEqual(payload["id"] as? String, "dev-1")
        XCTAssertEqual(payload["displayName"] as? String, "李莉")
        XCTAssertEqual(payload["ip"] as? String, "192.168.1.5")
        XCTAssertEqual(payload["busy"] as? Bool, false)
        XCTAssertEqual(payload["trusted"] as? Bool, true)
    }

    func testDeviceRemovedUsesIdNotDeviceId() throws {
        let event = WatchBridge.Event(type: .deviceRemoved, payload: .init(deviceId: "dev-9"))
        let payload = try XCTUnwrap(try encodeEvent(event)["payload"] as? [String: Any])
        XCTAssertEqual(payload["id"] as? String, "dev-9")
        XCTAssertNil(payload["deviceId"])
    }

    func testTransferProgressUsesIdNotTransferId() throws {
        let event = WatchBridge.Event(
            type: .transferProgress,
            payload: .init(transferId: "tx-3", bytesSent: 100, totalBytes: 1000)
        )
        let payload = try XCTUnwrap(try encodeEvent(event)["payload"] as? [String: Any])
        XCTAssertEqual(payload["id"] as? String, "tx-3")
        XCTAssertNil(payload["transferId"])
        XCTAssertEqual(payload["bytesSent"] as? Int, 100)
        XCTAssertEqual(payload["totalBytes"] as? Int, 1000)
    }

    func testOfferPayloadUsesFilesArray() throws {
        let offer = WatchBridge.OfferDTO(
            id: "offer-1", peerId: "dev-1", peerName: "嘉伟", kind: "file",
            files: [WatchBridge.FileMetaDTO(name: "slides.pdf", sizeBytes: 1024, mime: "application/pdf")],
            createdAt: 1700000000
        )
        let event = WatchBridge.Event(type: .offerPending, payload: .init(offer: offer))
        let payload = try XCTUnwrap(try encodeEvent(event)["payload"] as? [String: Any])
        XCTAssertNil(payload["offer"])
        XCTAssertNil(payload["fileName"])     // 废弃的单字段不应出现
        let files = try XCTUnwrap(payload["files"] as? [[String: Any]])
        XCTAssertEqual(files.first?["name"] as? String, "slides.pdf")
        XCTAssertEqual(files.first?["sizeBytes"] as? Int, 1024)
    }

    func testPairingPayloadHasCode() throws {
        let pairing = WatchBridge.PairingDTO(
            id: "pair-1", peerName: "孟茜", code: "QX8KL2",
            fingerprint: "abcd", createdAt: 1700000000
        )
        let event = WatchBridge.Event(type: .pairingPending, payload: .init(pairing: pairing))
        let payload = try XCTUnwrap(try encodeEvent(event)["payload"] as? [String: Any])
        XCTAssertNil(payload["pairing"])
        XCTAssertEqual(payload["code"] as? String, "QX8KL2")
        XCTAssertEqual(payload["fingerprint"] as? String, "abcd")
    }

    func testDeviceDtoDefaultsMatchSpec() {
        // model/ip 默认空串，rttMs 默认 0（companion-bridges.md §3.1）
        let dto = WatchBridge.DeviceDTO(id: "x", displayName: "n", kind: "ios")
        XCTAssertEqual(dto.model, "")
        XCTAssertEqual(dto.ip, "")
        XCTAssertEqual(dto.rttMs, 0)
        XCTAssertFalse(dto.busy)
    }

    func testConstantTimeEquals() {
        XCTAssertTrue(WebGateway.constantTimeEquals("LR4K7M", "LR4K7M"))
        XCTAssertFalse(WebGateway.constantTimeEquals("LR4K7M", "LR4K7N"))
        XCTAssertFalse(WebGateway.constantTimeEquals("LR4K7M", "LR4K7"))   // 长度不同
        XCTAssertTrue(WebGateway.constantTimeEquals("", ""))
    }
}
