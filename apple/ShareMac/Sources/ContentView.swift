import SwiftUI
import ShareKit

struct ContentView: View {
    @EnvironmentObject var engine: ShareEngine

    private var currentPairing: Binding<PairingRequest?> {
        Binding(get: { engine.pendingPairings.first }, set: { _ in })
    }

    private var currentOffer: Binding<PendingFileOffer?> {
        Binding(get: { engine.pendingFileOffers.first }, set: { _ in })
    }

    var body: some View {
        ZStack {
            BackgroundGradient()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        SelfBanner()
                        DeviceArea()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
                }

                if !engine.history.isEmpty {
                    HistoryView()
                }
            }
        }
        .frame(minWidth: 620, minHeight: 560)
        .sheet(item: currentPairing) { req in
            PairingSheet(request: req).environmentObject(engine)
        }
        .sheet(item: currentOffer) { offer in
            FileOfferSheet(offer: offer).environmentObject(engine)
        }
    }
}

/// 渐变背景。两端配色保持一致。
struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.84, green: 0.92, blue: 1.0),
                Color(red: 0.92, green: 0.88, blue: 1.0),
                Color(red: 1.0, green: 0.93, blue: 0.95),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
