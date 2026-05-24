import SwiftUI
import ShareKit

struct ContentView: View {
    @EnvironmentObject var engine: ShareEngine

    private var currentPairing: Binding<PairingRequest?> {
        Binding(
            get: { engine.pendingPairings.first },
            set: { _ in /* 通过 respondToPairing 改 */ }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    selfCard
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    DeviceListView()
                    InboxView()
                }
            }
            .navigationTitle("MeshDrop")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(item: currentPairing) { req in
            PairingSheet(request: req)
                .environmentObject(engine)
        }
    }

    private var selfCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.displayName)
                    .font(.headline)
                Text(engine.identity.fingerprint.prefix(16))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(engine.devices.count) 可见")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if !engine.trusted.isEmpty {
                    Text("已信任 \(engine.trusted.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.20), Color.purple.opacity(0.18), Color.pink.opacity(0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
