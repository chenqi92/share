import SwiftUI
import UIKit
import MeshDropKit

/// 剪贴板：显式推送一段文字到选中设备 + 查看收到的剪贴板推送。
/// 协议见 protocol/messages.md §0x11；非后台静默同步，由用户点一下才发。
struct ClipboardTab: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme

    @State private var draft: String = ""
    @FocusState private var editorFocused: Bool

    private var devices: [Device] { engine.devices }
    private var target: Device? {
        devices.first(where: { $0.id == state.selectedDeviceID }) ?? devices.first
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    composer
                    if engine.clipboardInbox.isEmpty {
                        emptyCard
                    } else {
                        AsciiDivider(MD("clipboard.inbox.section", engine.clipboardInbox.count))
                        ForEach(engine.clipboardInbox) { entry in
                            row(entry)
                        }
                    }
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { MeshDropLockup(size: 17) }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(MD("common.done")) { editorFocused = false }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(MD("clipboard.title"))
                .font(MeshDropFont.display(28, weight: .bold))
            Text(MD("clipboard.subtitle"))
                .font(MeshDropFont.display(18, weight: .semibold))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink60)
        }
    }

    // MARK: - 推送编辑器

    private var composer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(MD("clipboard.composer.pushTo"))
                    .font(MeshDropFont.mono(10.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                Menu {
                    if devices.isEmpty {
                        Text(MD("clipboard.noOnlineDevice"))
                    } else {
                        ForEach(devices, id: \.id) { d in
                            Button(d.name) { state.selectedDeviceID = d.id }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(target?.name ?? MD("common.selectDevice"))
                            .font(MeshDropFont.body(13, weight: .semibold))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(scheme == .dark ? Color.white : MeshDropColor.ink)
                }
                Spacer()
                Button {
                    if let s = UIPasteboard.general.string, !s.isEmpty { draft = s }
                } label: {
                    Label(MD("clipboard.composer.read"), systemImage: "doc.on.clipboard")
                        .font(MeshDropFont.mono(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(MeshDropColor.sky)
            }

            TextEditor(text: $draft)
                .focused($editorFocused)
                .font(MeshDropFont.body(14))
                .frame(minHeight: 90)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line)
                )

            HStack {
                Spacer()
                Button {
                    push()
                } label: {
                    Text(MD("clipboard.composer.push"))
                        .font(MeshDropFont.mono(11, weight: .bold))
                        .padding(.horizontal, 18).padding(.vertical, 8)
                        .background(
                            Capsule().fill(canPush ? MeshDropColor.lime : MeshDropColor.ink12)
                        )
                        .foregroundStyle(canPush ? MeshDropColor.ink : MeshDropColor.ink45)
                }
                .buttonStyle(.plain)
                .disabled(!canPush)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
    }

    private var canPush: Bool {
        target != nil && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func push() {
        guard let dev = target else { return }
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        engine.pushClipboard(to: dev, content: content, kind: Self.clipKind(content))
        draft = ""
        editorFocused = false
    }

    // MARK: - 收件行

    private func row(_ entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("↓ \(entry.peerName)")
                    .font(MeshDropFont.mono(10.5))
                    .foregroundStyle(MeshDropColor.sky)
                Spacer()
                Chip(entry.kind.uppercased(), tone: tone(entry.kind), mono: true)
            }
            Text(entry.content)
                .font(entry.kind == "code" ? MeshDropFont.mono(12) : MeshDropFont.body(13))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.9) : MeshDropColor.ink80)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            HStack {
                Spacer()
                Button {
                    UIPasteboard.general.string = entry.content
                } label: {
                    Label(MD("common.copy"), systemImage: "doc.on.doc")
                        .font(MeshDropFont.mono(10))
                }
                .buttonStyle(.plain)
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.6) : MeshDropColor.ink60)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
    }

    private func tone(_ kind: String) -> Chip.Tone {
        switch kind {
        case "link": return .sky
        case "code": return .flame
        default: return .outline
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Text(MD("clipboard.empty.title"))
                .font(MeshDropFont.body(14, weight: .semibold))
            Text(MD("clipboard.empty.subtitle"))
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
    }

    /// 按内容粗判 kind（与各端同口径）。
    static func clipKind(_ content: String) -> String {
        let t = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if (t.hasPrefix("http://") || t.hasPrefix("https://")),
           !t.contains(where: { $0.isWhitespace }) {
            return "link"
        }
        if t.contains("\n"), t.contains(where: { "{};=<>/".contains($0) }) {
            return "code"
        }
        return "text"
    }
}
