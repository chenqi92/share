import SwiftUI
import MeshDropKit
import PhotosUI
import UniformTypeIdentifiers
import UIKit

struct SendSheet: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    private let allowsKindSwitch: Bool
    @State private var kind: SendKind
    @State private var text: String = ""
    @State private var showFileImporter: Bool = false
    @State private var stagedFiles: [URL] = []
    @State private var stagedPhotos: [URL] = []
    @State private var photoSelection: [PhotosPickerItem] = []

    enum SendKind: String, CaseIterable, Identifiable {
        case text
        case clipboard
        case photo
        case file

        var id: String { rawValue }

        /// 分段选择器 / 标题里展示的本地化名称。
        var label: String {
            switch self {
            case .text:      return MD("send.kind.text")
            case .clipboard: return MD("send.kind.clipboard")
            case .photo:     return MD("send.kind.photo")
            case .file:      return MD("send.kind.file")
            }
        }
    }

    init(initialKind: SendKind = .text, allowsKindSwitch: Bool = true) {
        self.allowsKindSwitch = allowsKindSwitch
        _kind = State(initialValue: initialKind)
    }

    private var target: MockDevice {
        state.selectedDeviceDisplay(engine: engine)
    }

    private var realTarget: Device? {
        engine.devices.first(where: { $0.id == state.selectedDeviceID }) ?? engine.devices.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        targetRow
                        if allowsKindSwitch {
                            Picker("", selection: $kind) {
                                ForEach(SendKind.allCases) { k in
                                    Text(k.label).tag(k)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        switch kind {
                        case .text:
                            textBlock(title: MD("send.text.section"),
                                      placeholder: MD("send.text.placeholder"))
                        case .clipboard:
                            clipboardBlock
                        case .photo:
                            photoBlock
                        case .file:
                            fileBlock
                        }

                        Spacer(minLength: 30)
                        sendButton
                    }
                    .padding(20)
                }
            }
            .navigationTitle(allowsKindSwitch ? MD("send.title.general") : MD("send.title.kind", kind.label))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(MD("common.cancel")) { dismiss() }
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
            .onAppear {
                if kind == .clipboard { loadClipboardIfNeeded() }
            }
            .onChange(of: kind) { _, newKind in
                if newKind == .clipboard { loadClipboardIfNeeded() }
            }
            .onChange(of: photoSelection) { _, items in
                guard !items.isEmpty else { return }
                Task { await stagePhotos(items) }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var targetRow: some View {
        HStack(spacing: 12) {
            Avatar(initials: target.initials,
                   color: target.color, size: 36, online: target.isOnline)
            VStack(alignment: .leading, spacing: 2) {
                Text(realTarget == nil ? MD("common.selectDevice") : MD("send.target.toPeer", target.who))
                    .font(MeshDropFont.body(15, weight: .semibold))
                HStack(spacing: 6) {
                    KindGlyph(target.kind, size: 10)
                    Text(target.name)
                        .font(MeshDropFont.mono(10.5))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                }
            }
            Spacer()
            Chip("LAN", tone: .outline, mono: true, uppercased: true)
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

    private func textBlock(title: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider(title)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
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

    private var clipboardBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(MD("send.clipboard.title"))
                    .font(MeshDropFont.body(13, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                Spacer()
                Button {
                    readClipboard()
                } label: {
                    Label(MD("send.clipboard.read"), systemImage: "doc.on.clipboard")
                        .font(MeshDropFont.mono(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(MeshDropColor.sky)
            }
            textBlock(title: MD("send.clipboard.section"),
                      placeholder: MD("send.clipboard.placeholder"))
        }
    }

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsciiDivider(MD("send.photo.section", stagedPhotos.count))
            fileRows(stagedPhotos)
            PhotosPicker(selection: $photoSelection,
                         maxSelectionCount: 0,
                         matching: .images) {
                pickerButton(title: stagedPhotos.isEmpty ? MD("send.photo.choose") : MD("send.photo.add"),
                             systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.plain)
        }
    }

    private var fileBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            AsciiDivider(MD("send.file.section", stagedFiles.count))
            fileRows(stagedFiles)
            Button {
                showFileImporter = true
            } label: {
                pickerButton(title: stagedFiles.isEmpty ? MD("send.file.choose") : MD("send.file.add"),
                             systemImage: "plus.circle")
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func fileRows(_ urls: [URL]) -> some View {
        if urls.isEmpty {
            Text(MD("send.nothingSelected"))
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        } else {
            ForEach(urls, id: \.self) { url in
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
                FileChip(name: url.lastPathComponent,
                         size: HistoryItem.byteFormatter.string(fromByteCount: size),
                         ext: url.pathExtension)
            }
        }
    }

    private func pickerButton(title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
                .font(MeshDropFont.body(13, weight: .semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1, antialiased: true)
        )
    }

    private var canSend: Bool {
        guard realTarget != nil else { return false }
        switch kind {
        case .text, .clipboard:
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .photo:
            return !stagedPhotos.isEmpty
        case .file:
            return !stagedFiles.isEmpty
        }
    }

    private var sendButton: some View {
        Button(action: send) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .bold))
                Text(realTarget == nil ? MD("send.submit.selectDeviceFirst") : MD("send.submit.toPeer", target.who))
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
        case .clipboard:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            engine.pushClipboard(to: target, content: trimmed, kind: ClipboardTab.clipKind(trimmed))
        case .photo:
            engine.sendFiles(to: target, sourceURLs: stagedPhotos)
        case .file:
            engine.sendFiles(to: target, sourceURLs: stagedFiles)
        }
        dismiss()
    }

    private func loadClipboardIfNeeded() {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        readClipboard()
    }

    private func readClipboard() {
        if let value = UIPasteboard.general.string, !value.isEmpty {
            text = value
        }
    }

    private func stagePhotos(_ items: [PhotosPickerItem]) async {
        defer { photoSelection = [] }
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let ext = item.supportedContentTypes.first(where: { $0.preferredFilenameExtension != nil })?
                .preferredFilenameExtension ?? "jpg"
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("IMG-\(UUID().uuidString).\(ext)")
            do {
                try data.write(to: url)
                stagedPhotos.append(url)
            } catch {
                continue
            }
        }
    }
}
