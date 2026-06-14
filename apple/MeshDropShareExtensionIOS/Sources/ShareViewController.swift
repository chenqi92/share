import MeshDropKit
import MobileCoreServices
import OSLog
import Social
import UIKit
import UniformTypeIdentifiers

/// MeshDrop iOS Share Extension —— 出现在系统 share sheet 中。
///
/// 工作流：
/// 1. 用户在任意 app 点"分享" → 选择 MeshDrop
/// 2. 本扩展进程读 NSExtensionContext.inputItems 的 attachments
/// 3. 文字 / URL 直接 PendingShareQueue.enqueueText；文件在 loadFileRepresentation 的
///    completion closure 内、临时 URL 仍有效时同步 copy 到 App Group 容器 staging，再 enqueueFile
/// 4. 主 app 启动时 PendingShareQueue.drain 把 pending 项一个个发出
///
/// 当前实装将 peerID 暂存为占位 `"_pending_"`，主 app drain 时若找不到匹配 peer 就保留 —— 后续
/// 主 app UI 会监听 pending 项弹"选 peer"对话框。
final class ShareViewController: SLComposeServiceViewController {

    private let log = Logger(subsystem: "com.welape.meshdrop", category: "ShareExtension")

    /// 占位 peerID：drain 时若没匹配到实际设备就保留，等主 app UI 选目标。
    /// 复用 MeshDropKit 里的共享常量，保证扩展与主 app 两端一致。
    private static let unresolvedPeerID = PendingShareQueue.unresolvedPeerID

    override func isContentValid() -> Bool {
        // 文本或附件至少要有一个
        let hasText = !(contentText ?? "").isEmpty
        let hasAttachments = !(extensionContext?.inputItems
            .compactMap { ($0 as? NSExtensionItem)?.attachments }
            .flatMap { $0 } ?? []).isEmpty
        return hasText || hasAttachments
    }

    override func didSelectPost() {
        Task { [weak self] in
            await self?.enqueueAndComplete()
        }
    }

    override func configurationItems() -> [Any]! {
        // 不引入"选目标 peer"配置项 —— peer 列表是 LAN 动态的，扩展进程没法发现。
        // 主 app drain 时由 UI 提示用户选目标。
        []
    }

    @MainActor
    private func enqueueAndComplete() async {
        let q = PendingShareQueue.shared
        let peer = Self.unresolvedPeerID

        // 1. 抓 contentText（用户在 share sheet 自己输的）
        let text = (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            _ = q.enqueueText(peerID: peer, content: text)
        }

        // 2. 抓 inputItems 里的 attachments
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        for item in items {
            for provider in item.attachments ?? [] {
                await handleProvider(provider, queue: q, peer: peer)
            }
        }

        // 3. 通知主 app 有新 pending（主 app 启动时 drain；这里 OS 不允许唤起主 app）
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func handleProvider(_ provider: NSItemProvider, queue q: PendingShareQueue, peer: String) async {
        // 文字 / URL
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await loadItem(provider, type: UTType.url) as? URL {
                _ = q.enqueueText(peerID: peer, content: url.absoluteString)
                return
            }
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let s = try? await loadItem(provider, type: UTType.plainText) as? String {
                _ = q.enqueueText(peerID: peer, content: s)
                return
            }
        }
        // 文件 / 图片 / 视频 —— loadFileRepresentation 给的临时 URL 只在 completion closure
        // 返回前有效，closure 一返回系统就清理。所以必须在 closure 内、URL 仍有效时就把字节
        // 复制到 App Group container 的 staging 区，再把这个稳定的 staging URL 交给
        // enqueueFile 落入待发队列。enqueueFile 用后即从 staging 删除，避免重复占用。
        for typeID in [UTType.fileURL.identifier, UTType.image.identifier, UTType.movie.identifier, UTType.data.identifier] {
            if provider.hasItemConformingToTypeIdentifier(typeID) {
                if let staged = await stageFile(provider, typeID: typeID) {
                    _ = q.enqueueFile(peerID: peer, sourceURL: staged)
                    try? FileManager.default.removeItem(at: staged)
                    return
                }
            }
        }
    }

    private func loadItem(_ provider: NSItemProvider, type: UTType) async throws -> Any? {
        try await withCheckedThrowingContinuation { cont in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { item, err in
                if let err = err { cont.resume(throwing: err) } else { cont.resume(returning: item) }
            }
        }
    }

    /// 在 `loadFileRepresentation` 的 completion closure 内、临时 URL 仍有效时同步把字节
    /// 复制到 App Group container 的 staging 区，返回稳定的 staging URL。
    /// 关键：绝不把临时 URL 透传到 closure 之外再异步用 —— 那样 closure 一返回文件就被清理，
    /// 会间歇性丢文件（设备越忙、文件越大越易复现）。
    private func stageFile(_ provider: NSItemProvider, typeID: String) async -> URL? {
        await withCheckedContinuation { cont in
            _ = provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, err in
                if let err = err {
                    self.log.error("loadFileRepresentation 失败：\(err.localizedDescription)")
                    cont.resume(returning: nil)
                    return
                }
                guard let url else {
                    cont.resume(returning: nil)
                    return
                }
                // URL 此刻仍有效：同步 copy 到 staging，成功后才 resume 返回稳定路径。
                let staged = self.stageURL(named: url.lastPathComponent)
                let fm = FileManager.default
                do {
                    if fm.fileExists(atPath: staged.path) {
                        try fm.removeItem(at: staged)
                    }
                    try fm.copyItem(at: url, to: staged)
                    cont.resume(returning: staged)
                } catch {
                    self.log.error("staging 复制失败：\(error.localizedDescription)")
                    cont.resume(returning: nil)
                }
            }
        }
    }

    /// App Group container 内的 staging 子目录，用于在临时 URL 失效前先落盘字节。
    private func stageURL(named name: String) -> URL {
        let fm = FileManager.default
        let base = PendingShareQueue.containerURL ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("share-staging", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // 加 uuid 前缀，避免同名文件互相覆盖。
        let safeName = name.isEmpty ? "file" : name
        return dir.appendingPathComponent("\(UUID().uuidString)-\(safeName)")
    }
}
