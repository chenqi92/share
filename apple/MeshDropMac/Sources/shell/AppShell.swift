import SwiftUI

/// 主窗口：sidebar + content + traffic lights 让位 + 底部状态条。
struct AppShell: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            MeshDropColor.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if showsSidebar {
                        Sidebar()
                    }
                    contentRouter
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showsStatusBar {
                    StatusBar()
                }
            }
        }
        .frame(minWidth: 1180, minHeight: 760)
    }

    /// onboarding / receive / menubar 三个全屏视图不显示 sidebar。
    private var showsSidebar: Bool {
        switch state.tab {
        case .onboarding, .receive, .menubar: return false
        default: return true
        }
    }
    private var showsStatusBar: Bool {
        switch state.tab {
        case .onboarding, .receive, .menubar: return false
        default: return true
        }
    }

    @ViewBuilder
    private var contentRouter: some View {
        switch state.tab {
        case .discovery:  DiscoveryPage()
        case .chat:       ChatPage()
        case .transfers:  TransfersPage()
        case .history:    HistoryPage()
        case .clipboard:  ClipboardPage()
        case .trust:      TrustPage()
        case .settings:   SettingsPage()
        case .pairing:    PairingPage()
        case .onboarding: OnboardingPage()
        case .receive:    ReceivePage()
        case .menubar:    MenuBarPreviewPage()
        case .dragdrop:   ChatPage(forceDragOverlay: true)
        }
    }
}
