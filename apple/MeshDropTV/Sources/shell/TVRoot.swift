import SwiftUI

struct TVRoot: View {
    @State private var tab: TVTab = .receive

    var body: some View {
        ZStack {
            MeshDropColor.ambient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TVTopBar(selection: $tab)
                    .frame(height: 112)              // 固定高度，切换 tab 时永远不变
                    .frame(maxWidth: .infinity)
                    .transaction { txn in
                        txn.disablesAnimations = true
                    }

                Group {
                    switch tab {
                    case .receive:  ReceivePage()
                    case .nearby:   NearbyPage()
                    case .gallery:  GalleryPage()
                    case .pairing:  PairingPage()
                    case .settings: SettingsPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 90)
                .padding(.top, 16)
                .padding(.bottom, 50)
                .animation(nil, value: tab)
                .transaction { txn in
                    txn.disablesAnimations = true
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
    }
}
