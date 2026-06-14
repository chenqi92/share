import AppKit
import SwiftUI
import MeshDropKit

struct ClipboardPage: View {
    @EnvironmentObject var state: AppState

    private var inbox: [ClipboardEntry] { state.clipboardInbox }

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("clipboard.title")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("clipboard.title.suffix")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                    pushButton
                }

                HStack(spacing: 6) {
                    Circle().fill(MeshDropColor.limeDeep).frame(width: 6, height: 6)
                    Text(String(format: String(localized: "clipboard.summary"), inbox.count))
                        .font(MeshDropFont.mono(size: 11))
                        .foregroundStyle(MeshDropColor.textMuted)
                }

                AsciiDivider(text: String(format: String(localized: "clipboard.divider.inbox"), inbox.count))

                if inbox.isEmpty {
                    emptyView
                } else {
                    VStack(spacing: 10) {
                        ForEach(inbox) { clipRow($0) }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    /// 把本机剪贴板内容推给当前选中设备。空剪贴板 / 无选中设备时禁用。
    private var pushButton: some View {
        Button(action: pushCurrentClipboard) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.up.doc.on.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                Text(String(format: String(localized: "clipboard.push.button"), state.selectedDevice.who))
                    .font(MeshDropFont.body(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(MeshDropColor.lime))
            .foregroundStyle(MeshDropColor.ink)
        }
        .buttonStyle(.plain)
        .disabled(!state.canSendToSelectedDevice)
        .opacity(state.canSendToSelectedDevice ? 1 : 0.5)
        .help("clipboard.push.help")
    }

    private func pushCurrentClipboard() {
        guard state.canSendToSelectedDevice,
              let content = NSPasteboard.general.string(forType: .string),
              !content.isEmpty else { return }
        state.pushClipboard(toDeviceID: state.selectedDeviceID, content: content)
    }

    private var emptyView: some View {
        VStack(spacing: 8) {
            Text("clipboard.empty.title")
                .font(MeshDropFont.body(size: 13, weight: .medium))
                .foregroundStyle(MeshDropColor.textMuted)
            Text("clipboard.empty.detail")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func clipRow(_ c: ClipboardEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 5) {
                Avatar(initials: String(c.peerName.prefix(2)),
                       color: avatarColor(for: c.peerName),
                       size: 32)
                Text(Self.ago(c.receivedAt))
                    .font(MeshDropFont.mono(size: 9))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(c.peerName)
                        .font(MeshDropFont.body(size: 12, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Chip(text: kindText(c.kind), tone: kindTone(c.kind), mono: true)
                    Spacer()
                    Button(action: { copyToPasteboard(c.content) }) {
                        Text("⌘C")
                            .font(MeshDropFont.mono(size: 10))
                            .foregroundStyle(MeshDropColor.textMuted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(MeshDropColor.divider, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("clipboard.copy.help")
                }
                Text(c.content)
                    .font(c.kind == "code" ? MeshDropFont.mono(size: 12) : MeshDropFont.body(size: 13))
                    .foregroundStyle(c.kind == "link" ? MeshDropColor.sky : MeshDropColor.textPrimary)
                    .lineLimit(6)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(c.kind == "code" ? MeshDropColor.dink.opacity(0.06) : MeshDropColor.cardBg2)
                    )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeshDropColor.cardBg)
                .shadow(color: MeshDropColor.ink06, radius: 2, x: 0, y: 1)
        )
    }

    private func copyToPasteboard(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    private func kindText(_ k: String) -> String {
        switch k {
        case "link": return "LINK"
        case "code": return "CODE"
        default:     return "TEXT"
        }
    }
    private func kindTone(_ k: String) -> ChipTone {
        switch k {
        case "link": return .lime
        case "code": return .ink
        default:     return .outline
        }
    }
    private func avatarColor(for who: String) -> Color {
        let palette: [UInt32] = [0xC7B8FF, 0xFFD970, 0xFFB4A1, 0xB7E5C8, 0x9AD0FF]
        let i = abs(who.hashValue) % palette.count
        return Color(hex: palette[i])
    }

    private static func ago(_ date: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(date)))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}
