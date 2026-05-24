import SwiftUI
import AppKit
import ShareKit

struct SendSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    let device: Device

    enum Mode: String, CaseIterable, Identifiable {
        case text = "文本"
        case file = "文件"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .text
    @State private var text: String = ""
    @State private var selectedFile: URL?
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Group {
                switch mode {
                case .text: textArea
                case .file: fileArea
                }
            }

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("发送") { send() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSend)
            }
        }
        .padding(20)
        .frame(width: 480)
        .onAppear { textFocused = true }
    }

    private var header: some View {
        HStack(spacing: 12) {
            MiniDeviceBadge(os: device.os)
            VStack(alignment: .leading, spacing: 2) {
                Text("发送到 \(device.name)")
                    .font(.headline)
                Text(device.humanFingerprint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospaced()
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private var textArea: some View {
        TextEditor(text: $text)
            .focused($textFocused)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(8)
            .frame(minHeight: 140)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.regularMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    private var fileArea: some View {
        Group {
            if let url = selectedFile {
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(url.lastPathComponent)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(fileSizeLabel(for: url))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("更换") { pickFile() }
                        .buttonStyle(.borderless)
                }
                .padding(14)
                .frame(minHeight: 140)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.regularMaterial))
            } else {
                Button(action: pickFile) {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("选择文件")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.06)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(.secondary.opacity(0.4))
                    )
                }
                .buttonStyle(.plain)
                .frame(minHeight: 140)
            }
        }
    }

    private var canSend: Bool {
        switch mode {
        case .text: return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return selectedFile != nil
        }
    }

    private func send() {
        switch mode {
        case .text:
            engine.sendText(to: device, content: text)
        case .file:
            if let url = selectedFile {
                engine.sendFile(to: device, sourceURL: url)
            }
        }
        dismiss()
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        if panel.runModal() == .OK { selectedFile = panel.url }
    }

    private func fileSizeLabel(for url: URL) -> String {
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value) ?? 0
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}

/// 小尺寸设备图标，用于 sheet header 等紧凑场合。
struct MiniDeviceBadge: View {
    let os: DeviceOS

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 36, height: 36)
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    var gradient: [Color] {
        switch os {
        case .ios:     return [.blue, .indigo]
        case .android: return [.green, .mint]
        case .macos:   return [.purple, .pink]
        case .windows: return [.cyan, .blue]
        case .linux:   return [.orange, .red]
        }
    }

    var icon: String {
        switch os {
        case .ios:     return "iphone"
        case .android: return "candybarphone"
        case .macos:   return "macbook"
        case .windows: return "pc"
        case .linux:   return "desktopcomputer"
        }
    }
}
