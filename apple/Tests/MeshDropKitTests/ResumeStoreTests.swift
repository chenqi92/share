import XCTest
@testable import MeshDropKit

final class ResumeStoreTests: XCTestCase {
    private func makeTempStore() -> (URL, ResumeStore) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-test-\(UUID().uuidString).json")
        return (url, ResumeStore(storeURL: url))
    }

    private func sampleRecord(
        fp: String = "AA112233",
        sha: String = "deadbeef",
        bytesDone: UInt64 = 100,
        fileSize: UInt64 = 500
    ) -> ResumeRecord {
        ResumeRecord(
            peerFingerprint: fp,
            transferID: UUID(),
            fileName: "file.bin",
            fileSize: fileSize,
            sha256: sha,
            savedPath: "/tmp/file.bin",
            bytesDone: bytesDone,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testEmptyStoreFindReturnsNil() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }
        let result = await store.find(peerFingerprint: "AA", sha256: "BB")
        XCTAssertNil(result)
    }

    func testUpsertAndFind() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        let rec = sampleRecord()
        await store.upsert(rec)

        let found = await store.find(peerFingerprint: "AA112233", sha256: "deadbeef")
        XCTAssertEqual(found?.bytesDone, 100)
        XCTAssertEqual(found?.fileSize, 500)
        XCTAssertEqual(found?.fileName, "file.bin")
    }

    func testUpsertReplacesByKey() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        await store.upsert(sampleRecord(bytesDone: 100))
        await store.upsert(sampleRecord(bytesDone: 250))

        let found = await store.find(peerFingerprint: "AA112233", sha256: "deadbeef")
        XCTAssertEqual(found?.bytesDone, 250)
        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.count, 1)
    }

    func testDifferentPeerOrShaCoexist() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        await store.upsert(sampleRecord(fp: "AA", sha: "S1", bytesDone: 10))
        await store.upsert(sampleRecord(fp: "AA", sha: "S2", bytesDone: 20))
        await store.upsert(sampleRecord(fp: "BB", sha: "S1", bytesDone: 30))

        let snapshot = await store.snapshot()
        XCTAssertEqual(snapshot.count, 3)
        let aaS1 = await store.find(peerFingerprint: "AA", sha256: "S1")
        XCTAssertEqual(aaS1?.bytesDone, 10)
        let bbS1 = await store.find(peerFingerprint: "BB", sha256: "S1")
        XCTAssertEqual(bbS1?.bytesDone, 30)
    }

    func testClearRemovesOnlyMatchingKey() async {
        let (url, store) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        await store.upsert(sampleRecord(fp: "AA", sha: "S1"))
        await store.upsert(sampleRecord(fp: "AA", sha: "S2"))
        await store.clear(peerFingerprint: "AA", sha256: "S1")

        let s1 = await store.find(peerFingerprint: "AA", sha256: "S1")
        let s2 = await store.find(peerFingerprint: "AA", sha256: "S2")
        XCTAssertNil(s1)
        XCTAssertNotNil(s2)
    }

    func testPersistAcrossInstances() async throws {
        let (url, store1) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: url) }

        await store1.upsert(sampleRecord(bytesDone: 42))

        // 新实例从同一 url 加载，应能看到上一实例写的记录
        let store2 = ResumeStore(storeURL: url)
        let found = await store2.find(peerFingerprint: "AA112233", sha256: "deadbeef")
        XCTAssertEqual(found?.bytesDone, 42)
    }

    func testKeyDerivation() {
        let key = ResumeRecord.makeKey(peerFingerprint: "FP123", sha256: "ABC")
        XCTAssertEqual(key, "FP123:ABC")
    }
}
