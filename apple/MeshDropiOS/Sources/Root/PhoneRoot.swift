import SwiftUI

struct PhoneRoot: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TabView(selection: $state.phoneTab) {
            NavigationStack { DiscoverTab() }
                .tabItem { Label("附近", systemImage: "dot.radiowaves.left.and.right") }
                .tag(PhoneTab.discover)

            NavigationStack { ChatListTab() }
                .tabItem { Label("聊天", systemImage: "message") }
                .badge(2)
                .tag(PhoneTab.chats)

            NavigationStack { TransferTab() }
                .tabItem { Label("传输", systemImage: "arrow.up.arrow.down") }
                .tag(PhoneTab.transfers)

            NavigationStack { MeTab() }
                .tabItem { Label("我", systemImage: "person.circle") }
                .tag(PhoneTab.me)
        }
        .tint(MeshDropColor.limeDeep)
        .sheet(isPresented: $state.showSendSheet) { SendSheet() }
        .sheet(isPresented: $state.showOfferSheet) { FileOfferSheet() }
        .sheet(isPresented: $state.showPairingSheet) { PairingSheet() }
        .sheet(isPresented: $state.showOnboarding) { OnboardingSheet() }
        .sheet(isPresented: $state.showSettings) { NavigationStack { SettingsScreen() } }
        .sheet(isPresented: $state.showTrustManager) { NavigationStack { TrustManagerScreen() } }
        .sheet(isPresented: $state.showHistory) { NavigationStack { HistoryScreen() } }
#if DEBUG
        .sheet(isPresented: $state.showShareExt) { NavigationStack { ShareExtensionMock() } }
#endif
        .sheet(isPresented: $state.showLiveActivity) { NavigationStack { LiveActivityMock() } }
    }
}
