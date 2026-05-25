import SwiftUI
import MeshDropKit

struct PadRoot: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var padSection: PadSection = .chat

    enum PadSection: Hashable { case chat, transfers, history, settings, trust }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            DiscoverSidebar(section: $padSection)
                .navigationBarHidden(true)
        } detail: {
            switch padSection {
            case .chat:      ChatDetailScreen(device: state.selectedDeviceDisplay(engine: engine))
            case .transfers: TransferTab()
            case .history:   HistoryScreen()
            case .settings:  SettingsScreen()
            case .trust:     TrustManagerScreen()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $state.showSendSheet) { SendSheet() }
        .sheet(isPresented: $state.showOfferSheet) { FileOfferSheet() }
        .sheet(isPresented: $state.showPairingSheet) { PairingSheet() }
        .sheet(isPresented: $state.showOnboarding) { OnboardingSheet() }
#if DEBUG
        .sheet(isPresented: $state.showShareExt) { NavigationStack { ShareExtensionMock() } }
#endif
        .sheet(isPresented: $state.showLiveActivity) { NavigationStack { LiveActivityMock() } }
    }
}
