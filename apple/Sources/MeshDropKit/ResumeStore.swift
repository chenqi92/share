import Foundation
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "ResumeStore")

/// 中断的接收任务进度记录。
///
/// 以 `(peerFingerprint, sha256)` 作为去重键 — 不依赖 transfer_id，
/// 这样对端在断开后即使生成新 transfer_id（用户从历史项重发），只要文件内容一致
/// 接收端依旧能定位到之前写到一半的本地文件。
public struct ResumeRecord: Codable, Sendable, Equatable {
    public var peerFingerprint: String
    public var transferID: UUID
    public var fileName: String
    public var fileSize: UInt64
    public var sha256: String
    public var savedPath: String
    public var bytesDone: UInt64
    public var updatedAt: Date

    public init(
        peerFingerprint: String,
        transferID: UUID,
        fileName: String,
        fileSize: UInt64,
        sha256: String,
        savedPath: String,
        bytesDone: UInt64,
        updatedAt: Date
    ) {
        self.peerFingerprint = peerFingerprint
        self.transferID = transferID
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256 = sha256
        self.savedPath = savedPath
        self.bytesDone = bytesDone
        self.updatedAt = updatedAt
    }

    public static func makeKey(peerFingerprint: String, sha256: String) -> String {
        "\(peerFingerprint):\(sha256)"
    }

    public var key: String { Self.makeKey(peerFingerprint: peerFingerprint, sha256: sha256) }
}

/// 接收方持久化的「中断进度」库。
///
/// v0.1：明文 JSON，落到 `~/Library/Application Support/MeshDrop/resume.json`。
/// 完成或校验失败时调用方负责 [clear]；中断（连接异常关闭）时保留记录。
public actor ResumeStore {
    private var records: [String: ResumeRecord]
    private let url: URL

    public init(storeURL: URL? = nil) {
        self.url = storeURL ?? Self.defaultStoreURL()
        self.records = Self.load(from: url)
    }

    public func find(peerFingerprint: String, sha256: String) -> ResumeRecord? {
        records[ResumeRecord.makeKey(peerFingerprint: peerFingerprint, sha256: sha256)]
    }

    public func upsert(_ record: ResumeRecord) {
        records[record.key] = record
        persist()
    }

    public func clear(peerFingerprint: String, sha256: String) {
        records.removeValue(forKey: ResumeRecord.makeKey(peerFingerprint: peerFingerprint, sha256: sha256))
        persist()
    }

    public func snapshot() -> [ResumeRecord] {
        Array(records.values)
    }

    // MARK: - 持久化

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            log.error("persist failed: \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL) -> [String: ResumeRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: ResumeRecord].self, from: data)) ?? [:]
    }

    private static func defaultStoreURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MeshDrop", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("resume.json")
    }
}
