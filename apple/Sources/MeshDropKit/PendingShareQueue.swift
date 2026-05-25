import Foundation
import MeshDropKit
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
    public struct PendingItem: Codable {
        public let id: String
        public let peerID: String
        public let kind: Kind
        public let createdAt: Date

        public enum Kind: Codable {
            case text(String)
            case file(name: String, sizeBytes: UInt64)
        }
    }

    /// 主 app 启动时调：把所有待发项 drain 给 engine。
    public func drain(engine: ShareEngine) {
        guard let dir = Self.pendingDir else {
            log.debug("App Group container 不可用，跳过 drain（entitlement 未配置）")
            return
        }
        let entries: [URL]
        do {
            entries = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])
                .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        } catch {
            log.error("读取 pending 目录失败：\(error.localizedDescription)")
            return
        }
        for item in entries {
            drainOne(item, engine: engine)
        }
    }

    /// 单条 payload 的 drain：读 meta → 找 peer → engine.send* → 删目录。
    private func drainOne(_ itemDir: URL, engine: ShareEngine) {
        let metaURL = itemDir.appendingPathComponent("meta.json")
        guard let metaData = try? Data(contentsOf: metaURL),
              let meta = try? JSONDecoder().decode(PendingItem.self, from: metaData) else {
            log.error("无法解析 \(itemDir.lastPathComponent)/meta.json，已删除")
            try? fm.removeItem(at: itemDir)
            return
        }
        // peer 必须在线才能发，否则保留待下次 drain
        guard let peer = engine.devices.first(where: { $0.id == meta.peerID }) else {
            log.info("peer \(meta.peerID) 不在线，保留 \(meta.id) 等下次 drain")
            return
        }
        switch meta.kind {
        case .text(let content):
            engine.sendText(to: peer, content: content)
        case .file(let name, _):
            let fileURL = itemDir.appendingPathComponent(name)
            if fm.fileExists(atPath: fileURL.path) {
                engine.sendFile(to: peer, sourceURL: fileURL)
            } else {
                log.error("\(meta.id) 文件 \(name) 不存在，跳过")
            }
        }
        // engine.sendFile 是 async streaming：这里立即删 meta，但文件等 send 内部读完才能删。
        // 简化：删 meta 阻止重发，文件落在原地直到主 app 退出时由 OS 清理 / 下次 drain 略过。
        try? fm.removeItem(at: metaURL)
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
