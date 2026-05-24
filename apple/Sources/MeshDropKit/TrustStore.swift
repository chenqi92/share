import Foundation
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "TrustStore")

public struct TrustRecord: Codable, Sendable, Equatable, Identifiable {
    public var fingerprint: String
    public var name: String           // 配对时刻的设备名快照
    public var firstSeen: Date
    public var lastSeen: Date

    public var id: String { fingerprint }
}

/// 信任的设备指纹库。持久化到 `~/Library/Application Support/MeshDrop/trust.json`。
///
/// v0.1：明文 JSON。v1.0 切到 Keychain 或加密文件。
public actor TrustStore {
    private var records: [String: TrustRecord]
    private let url: URL

    public init() {
        self.url = Self.storeURL()
        self.records = Self.load(from: url)
    }

    public func isTrusted(_ fingerprint: String) -> Bool {
        records[fingerprint] != nil
    }

    public func trust(fingerprint: String, name: String) {
        let now = Date()
        if var existing = records[fingerprint] {
            existing.lastSeen = now
            existing.name = name
            records[fingerprint] = existing
        } else {
            records[fingerprint] = TrustRecord(
                fingerprint: fingerprint,
                name: name,
                firstSeen: now,
                lastSeen: now
            )
        }
        persist()
    }

    public func touch(fingerprint: String) {
        guard var rec = records[fingerprint] else { return }
        rec.lastSeen = Date()
        records[fingerprint] = rec
        persist()
    }

    public func revoke(_ fingerprint: String) {
        records.removeValue(forKey: fingerprint)
        persist()
    }

    public func snapshot() -> [TrustRecord] {
        records.values.sorted { $0.lastSeen > $1.lastSeen }
    }

    // MARK: - 持久化

    private func persist() {
        do {
            let data = try JSONEncoder().encode(records)
            try data.write(to: url, options: .atomic)
        } catch {
            log.error("persist failed: \(error.localizedDescription)")
        }
    }

    private static func load(from url: URL) -> [String: TrustRecord] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([String: TrustRecord].self, from: data)) ?? [:]
    }

    private static func storeURL() -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MeshDrop", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("trust.json")
    }
}
