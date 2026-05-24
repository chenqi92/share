import SwiftUI
import ShareKit

struct SendTextSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    let device: Device

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(minHeight: 160)
                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("发送文本")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") {
                        engine.sendText(to: device, content: text)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer()
        }
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
