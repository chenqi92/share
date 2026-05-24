import SwiftUI
import UniformTypeIdentifiers
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
    @State private var fileImporterShown = false
    @FocusState private var textFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
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

                Spacer(minLength: 0)
            }
            .padding(16)
            .navigationTitle("发送")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") { send() }
                        .disabled(!canSend)
                }
            }
            .onAppear { textFocused = true }
            .fileImporter(
                isPresented: $fileImporterShown,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    selectedFile = url
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(spacing: 10) {
            MiniDeviceBadge(os: device.os)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.headline)
                    .lineLimit(1)
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

    private var textArea: some View {
        TextEditor(text: $text)
            .focused($textFocused)
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: 160)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    Button("更换") { fileImporterShown = true }
                        .buttonStyle(.borderless)
                }
                .padding(14)
                .frame(minHeight: 140)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Button {
                    fileImporterShown = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("选择文件")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .liquidGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        case .text: engine.sendText(to: device, content: text)
        case .file:
            if let url = selectedFile { engine.sendFile(to: device, sourceURL: url) }
        }
        dismiss()
    }

    private func fileSizeLabel(for url: URL) -> String {
        let size = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value) ?? 0
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: size)
    }
}

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
