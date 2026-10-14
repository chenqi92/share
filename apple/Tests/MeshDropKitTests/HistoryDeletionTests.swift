import XCTest
@testable import MeshDropKit

final class HistoryDeletionTests: XCTestCase {
    private let peer = Device(id: "peer", name: "Peer", os: .ios, fingerprint: "abc", port: 0)

    func testOutgoingOriginalIsPreservedAndOwnedCopyCanBeRemoved() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let id = UUID()
        let original = root.appendingPathComponent("original.png")
        let owned = root.appendingPathComponent("Attachments/\(id.uuidString)/original.png")
        let originals = HistoryItem(id: id, peer: peer, direction: .outgoing, kind: .file(name: "original.png", size: 5, url: original), status: .completed)
        var copy = originals
        copy.kind = .file(name: "original.png", size: 5, url: owned)
        XCTAssertNil(HistoryDeletion.attachmentURL(for: originals, preserving: [], attachmentsDirectory: root.appendingPathComponent("Attachments")))
        XCTAssertEqual(HistoryDeletion.attachmentURL(for: copy, preserving: [], attachmentsDirectory: root.appendingPathComponent("Attachments")), owned)
    }

    func testIncomingFileStillUsedByAnotherEntryIsPreserved() {
        let file = URL(fileURLWithPath: "/tmp/shared-received.png")
        let first = HistoryItem(peer: peer, direction: .incoming, kind: .file(name: "image", size: 5, url: file), status: .completed)
        let second = HistoryItem(peer: peer, direction: .incoming, kind: first.kind, status: .completed)
        XCTAssertNil(HistoryDeletion.attachmentURL(for: first, preserving: [second], attachmentsDirectory: URL(fileURLWithPath: "/unused")))
        XCTAssertEqual(HistoryDeletion.attachmentURL(for: first, preserving: [], attachmentsDirectory: URL(fileURLWithPath: "/unused")), file)
    }

    func testDiscardedResumeCannotBeResurrectedByLateProgressSave() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("resume.json")
        let store = ResumeStore(storeURL: url)
        let record = ResumeRecord(peerFingerprint: "abc", transferID: UUID(), fileName: "private.png", fileSize: 10, sha256: "hash", savedPath: "/tmp/private.png", bytesDone: 5, updatedAt: Date())
        await store.upsert(record)
        try await store.discard(savedPath: record.savedPath, transferIDs: [record.transferID])
        await store.upsert(record)
        let reloaded = await ResumeStore(storeURL: url).snapshot()
        XCTAssertTrue(reloaded.isEmpty)
        XCTAssertFalse(try String(contentsOf: url).contains("private.png"))
    }
}


extension HistoryDeletionTests {
    func testDeletingOwnedCopyRemovesItsDirectoryButKeepsOriginal() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let id = UUID()
        let attachments = root.appendingPathComponent("Attachments")
        let directory = attachments.appendingPathComponent(id.uuidString)
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let original = root.appendingPathComponent("original.png")
        let owned = directory.appendingPathComponent("original.png")
        try Data("image content".utf8).write(to: original)
        try fm.copyItem(at: original, to: owned)
        let item = HistoryItem(id: id, peer: peer, direction: .outgoing, kind: .file(name: "original.png", size: 13, url: owned), status: .completed)
        try HistoryDeletion.removeAttachment(for: item, preserving: [], attachmentsDirectory: attachments)
        XCTAssertFalse(fm.fileExists(atPath: directory.path))
        XCTAssertEqual(try Data(contentsOf: original), Data("image content".utf8))
    }

    func testDeletedReceivedFileAndHistoryDoNotReturnAfterReload() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let file = root.appendingPathComponent("received-secret.png")
        try Data("private content".utf8).write(to: file)
        let item = HistoryItem(peer: peer, direction: .incoming, kind: .file(name: file.lastPathComponent, size: 15, url: file), status: .completed)
        let historyURL = root.appendingPathComponent("history.json")
        let store = HistoryStore(storeURL: historyURL)
        try await store.saveOrThrow([item])
        try HistoryDeletion.removeAttachment(for: item, preserving: [], attachmentsDirectory: root.appendingPathComponent("Attachments"))
        try await store.saveOrThrow([])
        let reloaded = await HistoryStore(storeURL: historyURL).load()
        XCTAssertTrue(reloaded.isEmpty)
        XCTAssertFalse(fm.fileExists(atPath: file.path))
        XCTAssertFalse(try String(contentsOf: historyURL).contains(item.id.uuidString))
        XCTAssertFalse(try String(contentsOf: historyURL).contains(file.lastPathComponent))
    }
}
