import SwiftUI
import MeshDropKit

@main
struct MeshDropApp: App {
    @StateObject private var state = AppState()
    @StateObject private var engine = ShareEngine.shared
    @StateObject private var watchSession = WatchSessionController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(engine)
                .tint(MeshDropColor.lime)
                .task {
                    #if DEBUG
                    if let route = ProcessInfo.processInfo.environment["MESHDROP_PREVIEW_ROUTE"] {
                        // 离线截图预览：只注入演示数据并跳转，不联网、不请求通知权限。
                        engine.seedPreviewData(route: route)
                        state.applyPreviewRouteFromEnvIfNeeded()
                        return
                    }
                    #endif
                    engine.start()
                    IncomingNotifier.startShared(engine: engine)
                    watchSession.start(engine: engine)
                    // 传输进度驱动 Live Activity（灵动岛 / 锁屏）。
                    LiveActivityManager.shared.attach(to: engine)
                    // 已确定 peer 的项直接发；未决项（占位 peer）交给「选目标」面板。
                    PendingShareQueue.shared.drain(engine: engine)
                    state.refreshPendingShares()
                    state.applyPreviewRouteFromEnvIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    // 从「分享」回到主 app 时再 drain + 刷新一次未决项。
                    guard phase == .active else { return }
                    PendingShareQueue.shared.drain(engine: engine)
                    state.refreshPendingShares()
                }
        }
    }
}

/// 全局 UI 状态（导航 / sheet 显隐 + 选中的设备 id）。设备 / 历史 / 待审等数据全部走
/// `ShareEngine.shared`，AppState 不再持有业务数据。
@MainActor
final class AppState: ObservableObject {
    @Published var selectedDeviceID: String = ""
    @Published var phoneTab: PhoneTab = .discover
    @Published var showSendSheet: Bool = false
    @Published var sendSheetInitialKind: SendSheet.SendKind = .text
    @Published var sendSheetAllowsKindSwitch: Bool = true
    @Published var showOfferSheet: Bool = false
    @Published var showPairingSheet: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var showSettings: Bool = false
    @Published var showHistory: Bool = false
    @Published var showTrustManager: Bool = false
    @Published var showClipboardSheet: Bool = false
    @Published var showShareExt: Bool = false
    @Published var showLiveActivity: Bool = false

    /// 来自 Share Extension 的未决分享项（占位 peer）。非空时弹「选目标」面板。
    @Published var pendingShares: [PendingShareQueue.ResolvedPendingItem] = []
    /// 「选目标」面板显隐。
    @Published var showPendingShareResolver: Bool = false

    /// 从队列重新载入未决项，有则弹面板。主 app 启动 / 回前台时调。
    func refreshPendingShares() {
        pendingShares = PendingShareQueue.shared.unresolvedItems()
        if !pendingShares.isEmpty { showPendingShareResolver = true }
    }

    func presentSend(_ kind: SendSheet.SendKind, allowsKindSwitch: Bool = true) {
        sendSheetInitialKind = kind
        sendSheetAllowsKindSwitch = allowsKindSwitch
        showSendSheet = true
    }

    /// 选中设备的 UI 展示模型。LAN 上没有任何设备时返回一个占位的"等待"卡片。
    func selectedDeviceDisplay(engine: ShareEngine) -> MockDevice {
        if !selectedDeviceID.isEmpty {
            if let real = engine.devices.first(where: { $0.id == selectedDeviceID }) {
                return real.displayMock
            }
            if let historical = engine.history.first(where: { $0.peer.id == selectedDeviceID }) {
                return historical.peer.displayMock(isOnline: false)
            }
        }
        if let any = engine.devices.first {
            return any.displayMock
        }
        return MockDevice.placeholder
    }

    /// 接受 `MESHDROP_PREVIEW_ROUTE` 环境变量，启动后直接跳到指定页面。
    /// 仅用于离线截图 / 设计预览，发布产物不会用到。
    func applyPreviewRouteFromEnvIfNeeded() {
        guard let raw = ProcessInfo.processInfo.environment["MESHDROP_PREVIEW_ROUTE"] else { return }
        switch raw {
        case "discover":      phoneTab = .discover
        case "chats":         phoneTab = .chats
        case "chat-detail":   phoneTab = .chats
        case "transfers":     phoneTab = .transfers
        case "me":            phoneTab = .me
        case "history":       phoneTab = .me; showHistory = true
        case "settings":      phoneTab = .me; showSettings = true
        case "trust":         phoneTab = .me; showTrustManager = true
        case "clipboard":     phoneTab = .chats; showClipboardSheet = true
        case "pairing":       phoneTab = .me; showPairingSheet = true
        case "onboarding":    showOnboarding = true
        case "receive":       phoneTab = .me; showOfferSheet = true
        case "send":          phoneTab = .discover; presentSend(.text)
        case "share-ext":     phoneTab = .me; showShareExt = true
        case "live-activity": phoneTab = .me; showLiveActivity = true
        default: break
        }
    }
}

enum PhoneTab: Hashable {
    case discover, chats, transfers, clipboard, me
}

extension MockDevice {
    /// 当 LAN 上一台设备都还没发现时的占位卡片。
    static let placeholder = MockDevice(
        id: "—", name: "等待设备", who: "—", kind: .ios,
        dist: 0, angle: 0, colorHex: 0xE5E7EB,
        initials: "··", os: "—", rtt: 0, isOnline: false
    )
}
