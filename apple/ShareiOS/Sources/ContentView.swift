import SwiftUI
import ShareKit

struct ContentView: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.horizontalSizeClass) var hSize

    private var currentPairing: Binding<PairingRequest?> {
        Binding(get: { engine.pendingPairings.first }, set: { _ in })
    }
    private var currentOffer: Binding<PendingFileOffer?> {
        Binding(get: { engine.pendingFileOffers.first }, set: { _ in })
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
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, engine.history.isEmpty ? 24 : 320)
                }

                if !engine.history.isEmpty {
                    VStack { Spacer(); HistoryView() }
                }
            }
            .navigationTitle("MeshDrop")
            .navigationBarTitleDisplayMode(hSize == .regular ? .large : .inline)
        }
        .sheet(item: currentPairing) { req in
            PairingSheet(request: req).environmentObject(engine)
        }
        .sheet(item: currentOffer) { offer in
            FileOfferSheet(offer: offer).environmentObject(engine)
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
