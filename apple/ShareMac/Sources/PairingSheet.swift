import SwiftUI
import ShareKit

struct PairingSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    let request: PairingRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .font(.title)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(request.peer.name) 想要连接到本设备")
                        .font(.headline)
                    Text("请确认对端指纹与对方设备上显示的完全一致再放行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("指纹")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(request.peer.humanFingerprint)
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
            }

            HStack {
                Button("拒绝", role: .destructive) {
                    engine.respondToPairing(request.id, decision: .reject)
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("允许一次") {
                    engine.respondToPairing(request.id, decision: .allowOnce)
                    dismiss()
                }
                Button("允许并记住") {
                    engine.respondToPairing(request.id, decision: .trust)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}
