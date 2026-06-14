import Foundation
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "HistoryStore")

/// 发送 / 接收历史的持久化库。镜像 [ResumeStore] / [TrustStore] 的明文 JSON 落盘范式，
/// 落到 `~/Library/Application Support/MeshDrop/history.json`（与 trust.json / resume.json 同目录）。
///
/// 与那两个库不同：历史是**有序时间线**（最新在前），所以底层用数组而非字典，整表覆盖写。
/// 上限 [maxItems] 条，超出截断最旧的，防止无限增长。
///
/// 设计取舍：引擎（[ShareEngine] @MainActor）持有内存里的 `history` 数组作为唯一真相，
/// 本 store 只负责「整表落盘 / 启动读回」。因此对外只暴露 `load()` 和 `save(_:)` 两个原子操作，
/// 引擎在历史**任何变更后**调一次 `save(currentHistory)` 即可，不在 store 里重复维护一份。
public actor HistoryStore {
    /// 历史上限。超出时由 [save] 截断最旧的（数组尾部）。
    public static let maxItems = 500

    private let url: URL

    public init(storeURL: URL? = nil) {
        self.url = storeURL ?? Self.defaultStoreURL()
    }

    /// 启动时读回历史（最新在前）。文件不存在 / 损坏时返回空数组，不抛错。
    public func load() -> [HistoryItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let items = (try? decoder.decode([HistoryItem].self, from: data)) ?? []
        // 防御：即使磁盘上的旧文件超限，读回也截断到上限。
        return Array(items.prefix(Self.maxItems))
    }

    /// 整表覆盖写。传入的数组应是「最新在前」的当前内存历史；超过上限自动截断尾部（最旧）。
    public func save(_ items: [HistoryItem]) {
        let capped = Array(items.prefix(Self.maxItems))
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(capped)
            try data.write(to: url, options: .atomic)
        } catch {
            log.error("save failed: \(error.localizedDescription)")
        }
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
        return dir.appendingPathComponent("history.json")
    }
}
