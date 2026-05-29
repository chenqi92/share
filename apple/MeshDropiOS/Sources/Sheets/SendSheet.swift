import SwiftUI
import MeshDropKit
import UniformTypeIdentifiers

struct SendSheet: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var kind: SendKind = .text
    @State private var text: String = ""
    @State private var showFileImporter: Bool = false
    @State private var stagedFiles: [URL] = []

    enum SendKind: String, CaseIterable, Identifiable {
        case text = "文本"
        case file = "文件"
        var id: String { rawValue }
    }

    private var target: MockDevice {
        state.selectedDeviceDisplay(engine: engine)
    }

    private var realTarget: Device? {
        engine.realDevice(for: state.selectedDeviceID)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        targetRow
                        Picker("", selection: $kind) {
                            ForEach(SendKind.allCases) { k in
                                Text(k.rawValue).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                        switch kind {
                        case .text:      textBlock
                        case .file:      fileBlock
                        }
                        Spacer(minLength: 30)
                        sendButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle("发送 · Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    stagedFiles.append(contentsOf: urls)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var targetRow: some View {
        HStack(spacing: 12) {
            Avatar(initials: target.initials,
                   color: target.color, size: 36, online: target.isOnline)
            VStack(alignment: .leading, spacing: 2) {
                Text(realTarget == nil ? "选择设备" : "发送给 \(target.who)")
                    .font(MeshDropFont.body(15, weight: .semibold))
                HStack(spacing: 6) {
                    KindGlyph(target.kind, size: 10)
                    Text(target.name)
                        .font(MeshDropFont.mono(10.5))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                }
            }
            Spacer()
            Chip("E2E", tone: .outline, mono: true, uppercased: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider("TEXT · 文本")
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("想写点什么…\n例如「方案已确认，明天发」")
                        .font(MeshDropFont.body(14))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.35) : MeshDropColor.ink45)
                        .padding(12)
                }
                TextEditor(text: $text)
                    .font(MeshDropFont.body(14.5))
                    .scrollContentBackground(.hidden)
                    .padding(8)
            }
            .frame(minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )
        }
    }

    private var fileBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider("FILE · 已选 \(stagedFiles.count) 个")
            ForEach(stagedFiles, id: \.self) { url in
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
                FileChip(name: url.lastPathComponent,
                         size: HistoryItem.byteFormatter.string(fromByteCount: size),
                         ext: url.pathExtension)
            }
            Button { showFileImporter = true } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text(stagedFiles.isEmpty ? "选择文件" : "继续添加文件")
                        .font(MeshDropFont.body(13, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1, antialiased: true)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var canSend: Bool {
        guard realTarget != nil else { return false }
        switch kind {
        case .text: return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return !stagedFiles.isEmpty
        }
    }

    private var sendButton: some View {
        Button(action: send) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .bold))
                Text(realTarget == nil ? "请先选择设备" : "发送给 \(target.who)")
                    .font(MeshDropFont.body(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(canSend ? MeshDropColor.lime : MeshDropColor.lime.opacity(0.4)))
            .foregroundStyle(MeshDropColor.ink)
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    private func send() {
        guard let target = realTarget else { return }
        switch kind {
        case .text:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            engine.sendText(to: target, content: trimmed)
        case .file:
            engine.sendFiles(to: target, sourceURLs: stagedFiles)
        }
        dismiss()
    }
}
