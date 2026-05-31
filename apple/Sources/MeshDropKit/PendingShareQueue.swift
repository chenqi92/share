import Foundation
import OSLog

/// Share Extension 与主 app 之间的"待发送"持久化队列。
///
/// Share Extension 是独立 process，无法直接调用 `ShareEngine.shared`（即便能调，发完就被 OS 终止
/// 导致 mDNS 注册和 TCP listener 还没起就被回收）。本轮按 backend prompt 选择 **App Group 队列方案**：
///
/// 1. Share Extension 把待发 payload + 文件副本写入 App Group container：
///    ```
///    let url = PendingShareQueue.containerURL!.appendingPathComponent("pending/<uuid>")
///    try fileData.write(to: url.appendingPathComponent("file"))
///    try metadata.write(to: url.appendingPathComponent("meta.json"))
///    ```
/// 2. 主 app 启动（`MeshDropApp.task`）调用 `PendingShareQueue.shared.drain(engine:)`，
///    把所有 `pending/<uuid>` 子目录逐项发出，发完即删。
///
/// 要求：项目 entitlements 里启用 App Group `group.com.welape.meshdrop`。本轮先打基础设施，
/// extension target + entitlements 加签由后续轮处理；当前 container 不可用时静默跳过。
@MainActor
public final class PendingShareQueue {
    public static let shared = PendingShareQueue()

    public static let appGroupID = "group.com.welape.meshdrop"

    /// 占位 peerID：share extension 入队时还不知道目标 peer（LAN 设备列表是动态的，扩展进程
    /// 看不到）。主 app drain 时遇到该值会保留，等用户在「选目标」UI 里挑设备再发。
    /// extension 端和主 app 端共用这个常量，避免字符串两处写死不一致。
    /// nonisolated：供 PendingItem（值类型，非 MainActor）和 extension 进程随处引用。
    public nonisolated static let unresolvedPeerID = "_pending_"

    private let log = Logger(subsystem: "com.welape.meshdrop", category: "PendingShareQueue")
    private let fm = FileManager.default

    /// App Group container 根目录。entitlement 未配置时返回 nil。
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    /// `pending/` 子目录：每条待发 payload 一个子目录。
    public static var pendingDir: URL? {
        guard let base = containerURL else { return nil }
        let dir = base.appendingPathComponent("pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// payload 元数据。share extension 序列化写入 `meta.json`。
    public struct PendingItem: Codable, Identifiable, Hashable {
        public let id: String
        public let peerID: String
        public let kind: Kind
        public let createdAt: Date

        public enum Kind: Codable, Hashable {
            case text(String)
            case file(name: String, sizeBytes: UInt64)
        }

        /// 目标 peer 是否还未确定（等用户在主 app 里选）。
        public var isUnresolved: Bool { peerID == PendingShareQueue.unresolvedPeerID }

        /// UI 摘要：文本取前若干字符，文件取文件名。
        public var summary: String {
            switch kind {
            case .text(let s):
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.count > 80 ? String(trimmed.prefix(80)) + "…" : trimmed
            case .file(let name, _):
                return name
            }
        }

        /// 字节数（文件项），文本项为 nil。
        public var sizeBytes: UInt64? {
            if case .file(_, let n) = kind { return n }
            return nil
        }
    }

    /// 一条待发项 + 其在 container 里的目录（主 app 选 peer / 消费时用）。
    public struct ResolvedPendingItem: Identifiable, Hashable {
        public let item: PendingItem
        public let itemDir: URL
        public var id: String { item.id }
    }

    /// 主 app 启动时调：把**已确定 peer**的待发项 drain 给 engine。
    /// 占位 peer（`_pending_`）的项会被跳过，留给主 app 的「选目标」UI 处理（见 `pendingItems()`）。
    public func drain(engine: ShareEngine) {
        for resolved in allPending() {
            // 占位 peer 的项不在这里发——等用户选 peer。
            guard !resolved.item.isUnresolved else { continue }
            drainOne(resolved, engine: engine)
        }
    }

    /// 列出所有待发项（含占位 peer 的）。主 app UI 据此判断是否要弹「选目标」面板。
    /// 最新创建的在前。
    public func pendingItems() -> [ResolvedPendingItem] {
        allPending().sorted { $0.item.createdAt > $1.item.createdAt }
    }

    /// 仅列出还没确定 peer 的待发项（UI 选目标用）。
    public func unresolvedItems() -> [ResolvedPendingItem] {
        pendingItems().filter { $0.item.isUnresolved }
    }

    /// 把一条待发项发给用户选定的 peer，发出后删除目录。
    /// 文本立即发；文件先把 container 里的副本复制到 engine 可长期持有的临时目录再发
    /// （container 副本随后删除，避免重复发送）。
    public func send(_ resolved: ResolvedPendingItem, to peer: Device, engine: ShareEngine) {
        let itemDir = resolved.itemDir
        switch resolved.item.kind {
        case .text(let content):
            engine.sendText(to: peer, content: content)
            try? fm.removeItem(at: itemDir)
        case .file(let name, _):
            let src = itemDir.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else {
                log.error("\(resolved.item.id) 文件 \(name) 不存在，删除该项")
                try? fm.removeItem(at: itemDir)
                return
            }
            // 复制出 container，让 engine 流式读取期间不依赖 container 生命周期。
            let staged = stagedCopyURL(name: name)
            do {
                if fm.fileExists(atPath: staged.path) { try fm.removeItem(at: staged) }
                try fm.copyItem(at: src, to: staged)
                engine.sendFile(to: peer, sourceURL: staged)
            } catch {
                log.error("暂存文件副本失败，直接用 container 副本发：\(error.localizedDescription)")
                engine.sendFile(to: peer, sourceURL: src)
            }
            try? fm.removeItem(at: itemDir)
        }
    }

    /// 丢弃一条待发项（用户在「选目标」UI 取消 / 删除）。
    public func discard(_ resolved: ResolvedPendingItem) {
        try? fm.removeItem(at: resolved.itemDir)
    }

    /// 扫描 `pending/` 下所有有效子目录，解析 meta.json。
    private func allPending() -> [ResolvedPendingItem] {
        guard let dir = Self.pendingDir else {
            log.debug("App Group container 不可用，跳过（entitlement 未配置）")
            return []
        }
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        } catch {
            log.error("读取 pending 目录失败：\(error.localizedDescription)")
            return []
        }
        return entries.compactMap { itemDir in
            let metaURL = itemDir.appendingPathComponent("meta.json")
            guard let metaData = try? Data(contentsOf: metaURL),
                  let meta = try? JSONDecoder().decode(PendingItem.self, from: metaData) else {
                log.error("无法解析 \(itemDir.lastPathComponent)/meta.json，已删除")
                try? fm.removeItem(at: itemDir)
                return nil
            }
            return ResolvedPendingItem(item: meta, itemDir: itemDir)
        }
    }

    /// 单条已确定 peer 的 payload drain：找 peer → engine.send* → 删目录。
    private func drainOne(_ resolved: ResolvedPendingItem, engine: ShareEngine) {
        let meta = resolved.item
        // peer 必须在线才能发，否则保留待下次 drain
        guard let peer = engine.devices.first(where: { $0.id == meta.peerID }) else {
            log.info("peer \(meta.peerID) 不在线，保留 \(meta.id) 等下次 drain")
            return
        }
        send(resolved, to: peer, engine: engine)
    }

    /// container 外的暂存副本路径（caches/MeshDropPendingSend/）。
    private func stagedCopyURL(name: String) -> URL {
        let base = (try? fm.url(for: .cachesDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MeshDropPendingSend", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // 加 uuid 前缀避免同名覆盖正在发送的另一份。
        return dir.appendingPathComponent(UUID().uuidString + "-" + name)
    }

    /// Share Extension 端调用：把一条待发 payload 写入 container。
    /// 主 app 启动时会被 `drain` 消费。返回 `false` 表示 App Group 未配置。
    @discardableResult
    public func enqueueText(peerID: String, content: String) -> Bool {
        guard let dir = Self.pendingDir else { return false }
        let id = UUID().uuidString
        let itemDir = dir.appendingPathComponent(id, isDirectory: true)
        do {
            try fm.createDirectory(at: itemDir, withIntermediateDirectories: true)
            let item = PendingItem(id: id, peerID: peerID, kind: .text(content), createdAt: Date())
            let data = try JSONEncoder().encode(item)
            try data.write(to: itemDir.appendingPathComponent("meta.json"))
            return true
        } catch {
            log.error("enqueueText 写盘失败：\(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    public func enqueueFile(peerID: String, sourceURL: URL) -> Bool {
        guard let dir = Self.pendingDir else { return false }
        let id = UUID().uuidString
        let itemDir = dir.appendingPathComponent(id, isDirectory: true)
        do {
            try fm.createDirectory(at: itemDir, withIntermediateDirectories: true)
            let name = sourceURL.lastPathComponent
            let dest = itemDir.appendingPathComponent(name)
            // Share extension 进程通常没有 source 的长期访问权限，必须 copy 到 container 持久化。
            try fm.copyItem(at: sourceURL, to: dest)
            let size = (try? fm.attributesOfItem(atPath: dest.path)[.size] as? NSNumber)?.uint64Value ?? 0
            let item = PendingItem(id: id, peerID: peerID,
                                   kind: .file(name: name, sizeBytes: size),
                                   createdAt: Date())
            let data = try JSONEncoder().encode(item)
            try data.write(to: itemDir.appendingPathComponent("meta.json"))
            return true
        } catch {
            log.error("enqueueFile 写盘失败：\(error.localizedDescription)")
            return false
        }
    }
}
