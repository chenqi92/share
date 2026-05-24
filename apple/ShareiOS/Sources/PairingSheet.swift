import SwiftUI
import ShareKit

struct PairingSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    let request: PairingRequest

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(request.peer.name) 想要连接")
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
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    Button {
                        engine.respondToPairing(request.id, decision: .trust)
                        dismiss()
                    } label: {
                        Text("允许并记住").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        engine.respondToPairing(request.id, decision: .allowOnce)
                        dismiss()
                    } label: {
                        Text("允许一次").frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)

                    Button(role: .destructive) {
                        engine.respondToPairing(request.id, decision: .reject)
                        dismiss()
                    } label: {
                        Text("拒绝").frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                }
            }
            .padding(20)
            .navigationTitle("配对请求")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()  // 强制用户做选择
    }
}
