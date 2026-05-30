import Foundation
import Combine
import UserNotifications

/// 监听 ShareEngine 的入站事件（文本 / 文件 / 文件 offer / 剪贴板），弹系统通知。
/// macOS 与 iOS 共用。启动时请求授权；用 seen 集合避免对启动前既有项补发。
@MainActor
public final class IncomingNotifier {
    private static var shared: IncomingNotifier?

    /// 幂等启动：首次创建并 start，重复调用忽略。两端 App 启动时调一次即可。
    public static func startShared(engine: ShareEngine) {
        if shared != nil { return }
        let n = IncomingNotifier(engine: engine)
        n.start()
        shared = n
    }

    private let engine: ShareEngine
    private var bag = Set<AnyCancellable>()
    private var seenHistory = Set<UUID>()
    private var seenClip = Set<UUID>()
    private var seenOffers = Set<UUID>()

    private init(engine: ShareEngine) { self.engine = engine }

    private func start() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // 初始化 seen 为当前内容，避免启动时为既有项补发通知。
        seenHistory = Set(engine.history.map(\.id))
        seenClip = Set(engine.clipboardInbox.map(\.id))
        seenOffers = Set(engine.pendingFileOffers.map(\.id))

        engine.$history
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.onHistory($0) }
            .store(in: &bag)
        engine.$clipboardInbox
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.onClipboard($0) }
            .store(in: &bag)
        engine.$pendingFileOffers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.onOffers($0) }
            .store(in: &bag)
    }

    private func onHistory(_ items: [HistoryItem]) {
        for it in items where !seenHistory.contains(it.id) {
            seenHistory.insert(it.id)
            guard it.direction == .incoming else { continue }
            switch it.kind {
            case .text(let t): post(title: it.peer.name, body: t)
            case .file(let name, _, _): post(title: "\(it.peer.name) 发来文件", body: name)
            }
        }
    }

    private func onClipboard(_ items: [ClipboardEntry]) {
        for e in items where !seenClip.contains(e.id) {
            seenClip.insert(e.id)
            post(title: "\(e.peerName) 推送了剪贴板", body: e.content)
        }
    }

    private func onOffers(_ offers: [PendingFileOffer]) {
        for o in offers where !seenOffers.contains(o.id) {
            seenOffers.insert(o.id)
            post(title: "\(o.peer.name) 想发文件给你", body: o.fileName)
        }
    }

    private func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = String(body.prefix(140))
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
