import XCTest
@testable import MeshDropKit

final class WatchFileOutboxTests: XCTestCase {
    func testBothArrivalOrdersAndDuplicateDelivery() throws {
        for commandFirst in [true, false] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let box = WatchFileOutbox(root: root)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: root) }
            let source = root.appendingPathComponent("system-temp")
            let bytes = Data("配对设备的文件".utf8)
            try bytes.write(to: source)
            var deliveries: [WatchFileOutbox.Delivery] = []
            let drain = {
                box.forward(available: ["peer": String(repeating: "a", count: 32)], send: { deliveries.append($0) }, onError: { XCTFail("\($0)") })
            }
            if commandFirst { try box.record(ref: "ref-1", peerID: "peer", name: "样本.txt"); drain() }
            try box.record(ref: "ref-1", peerID: "peer", name: "样本.txt",
                           fingerprint: String(repeating: "a", count: 32), file: source)
            box.forward(available: ["peer": String(repeating: "b", count: 32)],
                        send: { _ in XCTFail("Target identity changed") }, onError: { XCTFail("\($0)") })
            drain()
            try box.record(ref: "ref-1", peerID: "peer", name: "样本.txt")
            try bytes.write(to: source)
            try box.record(ref: "ref-1", peerID: "peer", name: "样本.txt", file: source)
            drain()
            let reopened = WatchFileOutbox(root: root)
            XCTAssertThrowsError(try reopened.record(ref: "ref-1", peerID: "unrelated-peer", name: "sample"))
            reopened.forward(available: ["peer": String(repeating: "a", count: 32)], send: { deliveries.append($0) }, onError: { XCTFail("\($0)") })
            XCTAssertEqual(deliveries.map(\.peerID), ["peer"])
            let delivered = try XCTUnwrap(deliveries.first?.url)
            XCTAssertEqual(delivered.lastPathComponent, "样本.txt")
            XCTAssertEqual(try Data(contentsOf: delivered), bytes)
        }
    }

    func testLegacyStagingAndDelayedPeerPreserveContentAndDestination() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let box = WatchFileOutbox(root: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data([3, 1, 4])
        let source = root.appendingPathComponent("WC-temp")
        try data.write(to: source)
        try box.record(ref: "legacy", peerID: nil, name: nil, file: source)
        box.forward(available: ["peer": String(repeating: "a", count: 32)], send: { _ in XCTFail("Missing route") }, onError: { XCTFail("\($0)") })
        try box.record(ref: "legacy", peerID: "peer", name: "../original.bin")
        XCTAssertThrowsError(try box.record(ref: "legacy", peerID: "other", name: "redirect"))
        XCTAssertThrowsError(try box.record(ref: "../other", peerID: "peer", name: "foo"))
        box.forward(available: ["other": String(repeating: "b", count: 32)], send: { _ in XCTFail("Wrong peer") }, onError: { XCTFail("\($0)") })
        let restarted = WatchFileOutbox(root: root)
        var sent: [URL] = []
        restarted.forward(available: ["peer": String(repeating: "a", count: 32)], send: { sent.append($0.url) }, onError: { XCTFail("\($0)") })
        XCTAssertEqual(sent.map(\.lastPathComponent), ["original.bin"])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(sent.first)), data)
    }
    func testCommandCanForwardFileStagedByPreviousPhoneVersion() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let box = WatchFileOutbox(root: root)
        let bytes = Data([1, 2])
        try bytes.write(to: root.appendingPathComponent("cmd-legacy"))
        try box.record(ref: "cmd-legacy", peerID: "peer", name: "迁移.bin")
        var files: [URL] = []
        box.forward(available: ["peer": String(repeating: "a", count: 32)], send: { files.append($0.url) }, onError: { XCTFail("\($0)") })
        XCTAssertEqual(files.map(\.lastPathComponent), ["迁移.bin"])
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(files.first)), bytes)
    }

}
