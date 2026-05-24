import SwiftUI
import ShareKit

struct SendTextSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    let device: Device

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: icon(for: device.os))
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("发送到 \(device.name)")
                        .font(.headline)
                    Text(device.humanFingerprint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
                Spacer()
            }

            TextEditor(text: $text)
                .focused($focused)
                .font(.body)
                .padding(8)
                .frame(minHeight: 120)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
                )

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("发送") {
                    engine.sendText(to: device, content: text)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { focused = true }
    }

    private func icon(for os: DeviceOS) -> String {
        switch os {
        case .ios:     return "iphone"
        case .android: return "candybarphone"
        case .macos:   return "laptopcomputer"
        case .windows: return "desktopcomputer"
        case .linux:   return "pc"
        }
    }
}
