import SwiftUI
import ShareKit

struct ContentView: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.horizontalSizeClass) var hSize

    private var currentPairing: Binding<PairingRequest?> {
        Binding(get: { engine.pendingPairings.first }, set: { _ in })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        SelfCard()
                            .padding(.horizontal, sidePadding)
                            .padding(.top, 12)
                        DeviceListView()
                    }
                    // iPad 屏宽过大时把内容压在中间宽度上限内，避免一行铺满显得空
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, engine.inbox.isEmpty ? 24 : 280)
                }

                if !engine.inbox.isEmpty {
                    VStack { Spacer(); InboxView() }
                }
            }
            .navigationTitle("MeshDrop")
            .navigationBarTitleDisplayMode(hSize == .regular ? .large : .inline)
        }
        .sheet(item: currentPairing) { req in
            PairingSheet(request: req).environmentObject(engine)
        }
    }

    private var sidePadding: CGFloat { hSize == .regular ? 32 : 16 }
    private var contentMaxWidth: CGFloat? { hSize == .regular ? 900 : nil }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.84, green: 0.92, blue: 1.0),
                Color(red: 0.92, green: 0.88, blue: 1.0),
                Color(red: 1.0, green: 0.93, blue: 0.95),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
