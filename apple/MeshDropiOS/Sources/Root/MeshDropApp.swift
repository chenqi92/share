import SwiftUI
import MeshDropKit

@main
struct MeshDropApp: App {
    @StateObject private var state = AppState()
    @StateObject private var engine = ShareEngine.shared
    @StateObject private var watchSession = WatchSessionController.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(engine)
                .tint(MeshDropColor.lime)
                .task {
                    engine.start()
                    watchSession.start(engine: engine)
                    PendingShareQueue.shared.drain(engine: engine)
                    state.applyPreviewRouteFromEnvIfNeeded()
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
    @Published var showOfferSheet: Bool = false
    @Published var showPairingSheet: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var showSettings: Bool = false
    @Published var showHistory: Bool = false
    @Published var showTrustManager: Bool = false
    @Published var showShareExt: Bool = false
    @Published var showLiveActivity: Bool = false

    /// 选中设备的 UI 展示模型。LAN 上没有任何设备时返回一个占位的"等待"卡片。
    func selectedDeviceDisplay(engine: ShareEngine) -> MockDevice {
        if let real = engine.devices.first(where: { $0.id == selectedDeviceID }) {
            return real.displayMock
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
        case "pairing":       phoneTab = .me; showPairingSheet = true
        case "onboarding":    showOnboarding = true
        case "receive":       phoneTab = .me; showOfferSheet = true
        case "send":          phoneTab = .discover; showSendSheet = true
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
