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
/// 3. 文字 / URL 直接 PendingShareQueue.enqueueText；文件 loadFileRepresentation 后 copy 到
///    App Group 容器再 enqueueFile
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
        // 文件 / 图片 / 视频 —— loadFileRepresentation 得到临时 URL，extension 进程结束就清理，
        // PendingShareQueue.enqueueFile 内部已经 copy 到 App Group container 持久化。
        for typeID in [UTType.fileURL.identifier, UTType.image.identifier, UTType.movie.identifier, UTType.data.identifier] {
            if provider.hasItemConformingToTypeIdentifier(typeID) {
                if let url = await loadFile(provider, typeID: typeID) {
                    _ = q.enqueueFile(peerID: peer, sourceURL: url)
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

    private func loadFile(_ provider: NSItemProvider, typeID: String) async -> URL? {
        await withCheckedContinuation { cont in
            _ = provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, err in
                if let err = err {
                    self.log.error("loadFileRepresentation 失败：\(err.localizedDescription)")
                    cont.resume(returning: nil)
                    return
                }
                cont.resume(returning: url)
            }
        }
    }
}
