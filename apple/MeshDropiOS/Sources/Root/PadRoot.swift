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
        .onAppear { presentIncomingPromptsIfNeeded() }
        .onChange(of: engine.pendingPairings.first?.id) { _, _ in
            presentIncomingPromptsIfNeeded()
        }
        .onChange(of: engine.pendingFileOffers.first?.id) { _, _ in
            presentIncomingPromptsIfNeeded()
        }
        .sheet(isPresented: $state.showSendSheet) {
            SendSheet(initialKind: state.sendSheetInitialKind,
                      allowsKindSwitch: state.sendSheetAllowsKindSwitch)
        }
        .sheet(isPresented: $state.showOfferSheet) { FileOfferSheet() }
        .sheet(isPresented: $state.showPairingSheet) { PairingSheet() }
        .sheet(isPresented: $state.showOnboarding) { OnboardingSheet() }
        .sheet(isPresented: $state.showClipboardSheet) { NavigationStack { ClipboardTab() } }
#if DEBUG
        .sheet(isPresented: $state.showShareExt) { NavigationStack { ShareExtensionMock() } }
#endif
        .sheet(isPresented: $state.showLiveActivity) { NavigationStack { LiveActivityMock() } }
        .sheet(isPresented: $state.showPendingShareResolver, onDismiss: {
            state.pendingShares = PendingShareQueue.shared.unresolvedItems()
        }) {
            PendingShareResolverSheet(items: state.pendingShares)
                .environmentObject(engine)
        }
    }

    private func presentIncomingPromptsIfNeeded() {
        if !engine.pendingPairings.isEmpty {
            state.showPairingSheet = true
        } else if !engine.pendingFileOffers.isEmpty {
            state.showOfferSheet = true
        }
    }
}
