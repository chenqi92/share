import SwiftUI

struct TVRoot: View {
    @State private var tab: TVTab = .receive

    var body: some View {
        ZStack {
            MeshDropColor.ambient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TVTopBar(selection: $tab)

                Group {
                    switch tab {
                    case .receive:  ReceivePage()
                    case .nearby:   NearbyPage()
                    case .gallery:  GalleryPage()
                    case .pairing:  PairingPage()
                    case .settings: SettingsPage()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 90)
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }
}
