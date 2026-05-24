import SwiftUI

@main
struct MeshDropApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .tint(MeshDropColor.lime)
                .task { state.applyPreviewRouteFromEnvIfNeeded() }
        }
    }
}

/// 全局 UI 状态（mock 数据驱动；不接 backend）。
@MainActor
final class AppState: ObservableObject {
    @Published var selectedDeviceID: String = "mengxi"
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
    @Published var liveActivityProgress: Double = 0.84

    var selectedDevice: MockDevice {
        Mock.devices.first(where: { $0.id == selectedDeviceID }) ?? Mock.devices[3]
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
    case discover, chats, transfers, me
}
