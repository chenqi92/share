import SwiftUI

struct SendSheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var kind: SendKind = .text
    @State private var text: String = ""

    enum SendKind: String, CaseIterable, Identifiable {
        case text = "文本"
        case file = "文件"
        case photo = "照片"
        case clipboard = "剪贴板"
        var id: String { rawValue }
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
                        case .photo:     photoBlock
                        case .clipboard: clipboardBlock
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
        }
        .presentationDetents([.medium, .large])
    }

    private var targetRow: some View {
        HStack(spacing: 12) {
            Avatar(initials: state.selectedDevice.initials,
                   color: state.selectedDevice.color, size: 36, online: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("发送给 \(state.selectedDevice.who)")
                    .font(MeshDropFont.body(15, weight: .semibold))
                HStack(spacing: 6) {
                    KindGlyph(state.selectedDevice.kind, size: 10)
                    Text(state.selectedDevice.name)
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
            AsciiDivider("FILE · 已选 2 个")
            FileChip(name: "iOS-mocks-final.zip", size: "48.6 MB", ext: "zip")
            FileChip(name: "release-notes.md",    size: "4.8 KB",  ext: "md")
            Button {} label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("继续添加文件")
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

    private var photoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider("PHOTOS · 已选 3 张")
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Photo(hue: 20 + i * 70)
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Spacer()
            }
        }
    }

    private var clipboardBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsciiDivider("CLIPBOARD · 剪贴板")
            ForEach(Mock.clipboard.prefix(3)) { item in
                clipboardRow(item)
            }
        }
    }

    private func clipboardRow(_ item: MockClipboardItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind == .link ? "link" : item.kind == .code ? "chevron.left.forwardslash.chevron.right" : "doc.text")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MeshDropColor.flame)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.body)
                    .font(item.kind == .code ? MeshDropFont.mono(12) : MeshDropFont.body(13))
                    .lineLimit(2)
                Text("\(item.who) · \(item.ago)")
                    .font(MeshDropFont.mono(10))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
    }

    private var sendButton: some View {
        Button { dismiss() } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .bold))
                Text("发送给 \(state.selectedDevice.who)")
                    .font(MeshDropFont.body(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Capsule().fill(MeshDropColor.lime))
            .foregroundStyle(MeshDropColor.ink)
        }
        .buttonStyle(.plain)
    }
}
