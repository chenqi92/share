import XCTest
@testable import MeshDropKit

final class HistoryStoreTests: XCTestCase {
    private func makeTempStore() -> (URL, HistoryStore) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("history-test-\(UUID().uuidString).json")
        return (url, HistoryStore(storeURL: url))
    }

    private func device(_ name: String = "李莉", os: DeviceOS = .macos, fp: String = "9f3a7c2e8b1d4056") -> Device {
        Device(id: "id-\(fp)", name: name, os: os, model: "Mac", fingerprint: fp, port: 9580)
    }

    /// 历史项相等性按「持久化语义」比较：id / direction / kind / status / createdAt 以及对端快照
    /// {fp, name, os}。运行时字段（peer.id / model / port）刻意不存盘，故不参与比较。
    private func assertSamePersisted(_ a: HistoryItem?, _ b: HistoryItem?, _ msg: String = "", file: StaticString = #filePath, line: UInt = #line) {
        guard let a, let b else { return XCTFail("nil item \(msg)", file: file, line: line) }
        XCTAssertEqual(a.id, b.id, msg, file: file, line: line)
        XCTAssertEqual(a.direction, b.direction, msg, file: file, line: line)
        XCTAssertEqual(a.kind, b.kind, msg, file: file, line: line)
        XCTAssertEqual(a.status, b.status, msg, file: file, line: line)
        XCTAssertEqual(a.createdAt, b.createdAt, msg, file: file, line: line)
        XCTAssertEqual(a.peer.fingerprint, b.peer.fingerprint, msg, file: file, line: line)
        XCTAssertEqual(a.peer.name, b.peer.name, msg, file: file, line: line)
        XCTAssertEqual(a.peer.os, b.peer.os, msg, file: file, line: line)
    }

    func testEmptyStoreLoadsEmpty() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let items = await store.load()
        XCTAssertTrue(items.isEmpty)
    }

    func testSaveAndLoadRoundTrip() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let textItem = HistoryItem(
            peer: device(),
            direction: .outgoing,
            kind: .text("改完了"),
            status: .completed,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let fileItem = HistoryItem(
            peer: device("坤", os: .android, fp: "1c2d3e4f5a6b7c8d"),
            direction: .incoming,
            kind: .file(name: "IMG.heic", size: 2_400_000, url: URL(fileURLWithPath: "/tmp/IMG.heic")),
            status: .transferring(bytesDone: 1_000, bytesTotal: 2_400_000),
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        await store.save([fileItem, textItem])

        let loaded = await store.load()
        XCTAssertEqual(loaded.count, 2)
        assertSamePersisted(loaded.first, fileItem)
        assertSamePersisted(loaded.last, textItem)
    }

    func testPeerSnapshotPreservesFpNameOS() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let item = HistoryItem(
            peer: device("孟茜", os: .ios, fp: "7788990011223344"),
            direction: .incoming,
            kind: .text("收到"),
            status: .completed
        )
        await store.save([item])

        let loaded = await store.load()
        let peer = try? XCTUnwrap(loaded.first?.peer)
        XCTAssertEqual(peer?.fingerprint, "7788990011223344")
        XCTAssertEqual(peer?.name, "孟茜")
        XCTAssertEqual(peer?.os, .ios)
    }

    func testFileURLAndStatusSurviveEncoding() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let failed = HistoryItem(
            peer: device(),
            direction: .outgoing,
            kind: .file(name: "a.bin", size: 99, url: URL(fileURLWithPath: "/var/tmp/a.bin")),
            status: .failed("校验失败")
        )
        await store.save([failed])

        let loaded = await store.load().first
        guard case let .file(name, size, fileURL) = loaded?.kind else {
            return XCTFail("kind not file")
        }
        XCTAssertEqual(name, "a.bin")
        XCTAssertEqual(size, 99)
        XCTAssertEqual(fileURL?.path, "/var/tmp/a.bin")
        XCTAssertEqual(loaded?.status, .failed("校验失败"))
    }

    func testCapTruncatesOldestOnSave() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        // 构造 600 条，最新在前（createdAt 递减）。save 应只保留前 500（最新的）。
        let base = Date(timeIntervalSince1970: 2_000_000_000)
        var items: [HistoryItem] = []
        for i in 0..<600 {
            items.append(HistoryItem(
                peer: device(),
                direction: .outgoing,
                kind: .text("m\(i)"),
                status: .completed,
                createdAt: base.addingTimeInterval(Double(-i))
            ))
        }
        await store.save(items)

        let loaded = await store.load()
        XCTAssertEqual(loaded.count, HistoryStore.maxItems)
        // 保留的是数组头部（最新），尾部最旧被截断
        assertSamePersisted(loaded.first, items.first)
        assertSamePersisted(loaded.last, items[HistoryStore.maxItems - 1])
    }

    func testLoadCapsOversizedFileOnDisk() async throws {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        // 直接写一份超限（510 条）的磁盘文件，模拟旧版本 / 外部写入；load 应截断到上限。
        var items: [HistoryItem] = []
        for i in 0..<510 {
            items.append(HistoryItem(
                peer: device(),
                direction: .incoming,
                kind: .text("x\(i)"),
                status: .completed
            ))
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(items).write(to: url, options: .atomic)

        let loaded = await store.load()
        XCTAssertEqual(loaded.count, HistoryStore.maxItems)
    }

    func testSaveOverwritesPreviousFile() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        await store.save([HistoryItem(peer: device(), direction: .outgoing, kind: .text("first"), status: .completed)])
        await store.save([HistoryItem(peer: device(), direction: .outgoing, kind: .text("second"), status: .completed)])

        let loaded = await store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.kind, .text("second"))
    }
}
