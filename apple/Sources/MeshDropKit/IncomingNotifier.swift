import Foundation
import Combine
import UserNotifications

/// 监听 ShareEngine 的入站事件（文本 / 文件 / 文件 offer / 剪贴板），弹系统通知。
/// macOS 与 iOS 共用。启动时请求授权；用 seen 集合避免对启动前既有项补发。
@MainActor
public final class IncomingNotifier: NSObject {
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
    #if os(macOS)
    private var seenPairings = Set<UUID>()
    #endif

    private init(engine: ShareEngine) { self.engine = engine }

    private func start() {
        #if os(macOS)
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        func action(_ id: String, _ key: String.LocalizationValue) -> UNNotificationAction {
            UNNotificationAction(identifier: id, title: String(localized: key), options: [.authenticationRequired])
        }
        let reject = action("reject", "receive.reject")
        let once = action("once", "overlay.pairing.thisTime")
        let pair = UNNotificationCategory(identifier: "pair", actions: [action("trust", "pairing.allowRemember"), once, reject],
                                          intentIdentifiers: [])
        let temporary = UNNotificationCategory(identifier: "pairOnce", actions: [once, reject], intentIdentifiers: [])
        let file = UNNotificationCategory(identifier: "file", actions: [action("accept", "overlay.offer.accept"), reject],
                                         intentIdentifiers: [])
        center.setNotificationCategories([pair, temporary, file])
        engine.$pendingPairings.sink { [weak self] in self?.onPairings($0) }.store(in: &bag)
        #endif
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        // 初始化 seen 为当前内容，避免启动时为既有项补发通知。
        seenHistory = Set(engine.history.map(\.id))
        seenClip = Set(engine.clipboardInbox.map(\.id))
        seenOffers = Set(engine.pendingFileOffers.map(\.decisionID))

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
            case .text(let t): post(title: it.peer.name, body: t, identifier: it.id.uuidString)
            case .file(let name, _, _): post(title: L10n.notifIncomingFile(peer: it.peer.name), body: name, identifier: it.id.uuidString)
            }
        }
    }

    private func onClipboard(_ items: [ClipboardEntry]) {
        for e in items where !seenClip.contains(e.id) {
            seenClip.insert(e.id)
            post(title: L10n.notifClipboard(peer: e.peerName), body: e.content)
        }
    }

    private func onOffers(_ offers: [PendingFileOffer]) {
        let current = Set(offers.map(\.decisionID))
        #if os(macOS)
        removeRequests(seenOffers.subtracting(current))
        #endif
        for o in offers where !seenOffers.contains(o.decisionID) {
            post(title: L10n.notifFileOffer(peer: o.peer.name), body: o.fileName,
                 identifier: o.decisionID.uuidString, category: "file")
        }
        seenOffers = current
    }

    #if os(macOS)
    private func onPairings(_ requests: [PairingRequest]) {
        let current = Set(requests.map(\.id))
        removeRequests(seenPairings.subtracting(current))
        for request in requests where !seenPairings.contains(request.id) {
            post(title: String(format: String(localized: "pairing.requestFrom"), request.peer.name),
                 body: request.peer.humanFingerprint, identifier: request.id.uuidString,
                 category: request.canRemember ? "pair" : "pairOnce")
        }
        seenPairings = current
    }

    private func removeRequests(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let identifiers = ids.map(\.uuidString)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    #endif

    static func removeNotification(for item: HistoryItem) async {
        #if !os(tvOS)
        let center = UNUserNotificationCenter.current()
        let body: String
        switch item.kind {
        case .text(let text): body = String(text.prefix(140))
        case .file(let name, _, _): body = String(name.prefix(140))
        }
        let delivered = await center.deliveredNotifications()
        let identifiers = delivered.filter {
            $0.request.identifier == item.id.uuidString ||
            ($0.request.content.body == body && ($0.request.content.title == item.peer.name ||
                $0.request.content.title == L10n.notifIncomingFile(peer: item.peer.name)))
        }.map { $0.request.identifier }
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        center.removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
        #endif
    }

    private func post(title: String, body: String, identifier: String = UUID().uuidString, category: String = "") {
        guard engine.notificationsEnabled else { return }
        #if os(tvOS)
        // tvOS 的 UNMutableNotificationContent 不支持 title/body/sound；接收端只在 app 内提示，不发系统通知。
        _ = (title, body)
        #else
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = category
        content.title = title
        content.body = String(body.prefix(140))
        content.sound = .default
        let req = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
        #endif
    }
}

#if os(macOS)
extension IncomingNotifier: UNUserNotificationCenterDelegate {
    public nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                                   didReceive response: UNNotificationResponse) async {
        guard let id = UUID(uuidString: response.notification.request.identifier) else { return }
        let category = response.notification.request.content.categoryIdentifier
        let action = response.actionIdentifier
        await MainActor.run {
            switch (category, action) {
            case ("pair", "trust"): engine.respondToPairing(id, decision: .trust)
            case ("pair", "once"), ("pairOnce", "once"): engine.respondToPairing(id, decision: .allowOnce)
            case ("pair", "reject"), ("pairOnce", "reject"): engine.respondToPairing(id, decision: .reject)
            case ("file", "accept"), ("file", "reject"):
                if let offer = engine.pendingFileOffers.first(where: { $0.decisionID == id }) {
                    engine.respondToFileOffer(offer.id, accept: action == "accept")
                }
            default: break
            }
        }
    }
}
#endif
