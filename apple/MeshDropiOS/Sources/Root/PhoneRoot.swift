import SwiftUI
import MeshDropKit

struct PhoneRoot: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TabView(selection: $state.phoneTab) {
            NavigationStack { DiscoverTab() }
                .tabItem { Label(MD("tab.discover"), systemImage: "dot.radiowaves.left.and.right") }
                .tag(PhoneTab.discover)

            NavigationStack { ChatListTab() }
                .tabItem { Label(MD("tab.send"), systemImage: "paperplane") }
                .badge(engine.unreadTotal)
                .tag(PhoneTab.chats)

            NavigationStack { TransferTab() }
                .tabItem { Label(MD("tab.transfers"), systemImage: "arrow.up.arrow.down") }
                .tag(PhoneTab.transfers)

            NavigationStack { MeTab() }
                .tabItem { Label(MD("tab.me"), systemImage: "person.circle") }
                .tag(PhoneTab.me)
        }
        .tint(MeshDropColor.limeDeep)
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
        .sheet(isPresented: $state.showSettings) { NavigationStack { SettingsScreen() } }
        .sheet(isPresented: $state.showTrustManager) { NavigationStack { TrustManagerScreen() } }
        .sheet(isPresented: $state.showHistory) { NavigationStack { HistoryScreen() } }
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
