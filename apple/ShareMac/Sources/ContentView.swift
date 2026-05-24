import SwiftUI
import ShareKit

struct ContentView: View {
    @EnvironmentObject var engine: ShareEngine

    /// 当前要弹 pairing sheet 的请求。绑定到 pendingPairings 的第一个元素。
    private var currentPairing: Binding<PairingRequest?> {
        Binding(
            get: { engine.pendingPairings.first },
            set: { _ in /* 通过 respondToPairing 改 */ }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            DeviceListView()
            InboxView()
        }
        .sheet(item: currentPairing) { req in
            PairingSheet(request: req)
                .environmentObject(engine)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.displayName)
                    .font(.headline)
                Text("指纹 \(engine.identity.fingerprint.prefix(8)) …")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(engine.devices.count) 个可见设备")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !engine.trusted.isEmpty {
                    Text("已信任 \(engine.trusted.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }
}
