import SwiftUI

struct ClipboardPage: View {
    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("剪贴板")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("· Clipboard")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                    Chip(text: "SYNCED", tone: .lime, mono: true)
                    Chip(text: "⌘V 取最近", tone: .outline, mono: false)
                }

                HStack(spacing: 6) {
                    Circle().fill(MeshDropColor.limeDeep).frame(width: 6, height: 6)
                    Text("5 条同步条目 · 来自局域网 4 台设备 · 仅本人可见 · 不上云")
                        .font(MeshDropFont.mono(size: 11))
                        .foregroundStyle(MeshDropColor.textMuted)
                }

                AsciiDivider(text: "INBOX · 收件箱 · 5")

                VStack(spacing: 10) {
                    ForEach(MockClip.all) { c in
                        clipRow(c)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    @ViewBuilder
    private func clipRow(_ c: MockClip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 5) {
                Avatar(initials: String(c.who.prefix(2)),
                       color: avatarColor(for: c.who),
                       size: 32)
                Text(c.ago)
                    .font(MeshDropFont.mono(size: 9))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(c.who)
                        .font(MeshDropFont.body(size: 12, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Chip(text: kindText(c.kind), tone: kindTone(c.kind), mono: true)
                    if let lang = c.lang {
                        Chip(text: lang.uppercased(), tone: .outline, mono: true)
                    }
                    Spacer()
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
                Text(c.body)
                    .font(c.kind == .code ? MeshDropFont.mono(size: 12) : MeshDropFont.body(size: 13))
                    .foregroundStyle(c.kind == .link ? MeshDropColor.sky : MeshDropColor.textPrimary)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(c.kind == .code ? MeshDropColor.dink.opacity(0.06) : MeshDropColor.cardBg2)
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

    private func kindText(_ k: ClipKind) -> String {
        switch k {
        case .link: return "LINK"
        case .text: return "TEXT"
        case .code: return "CODE"
        }
    }
    private func kindTone(_ k: ClipKind) -> ChipTone {
        switch k {
        case .link: return .lime
        case .text: return .outline
        case .code: return .ink
        }
    }
    private func avatarColor(for who: String) -> Color {
        switch who {
        case "嘉伟": return Color(hex: 0xC7B8FF)
        case "孟茜": return Color(hex: 0xFFD970)
        case "李莉": return Color(hex: 0xFFB4A1)
        case "坤":   return Color(hex: 0xB7E5C8)
        default:     return Color(hex: 0xE2DCCD)
        }
    }
}
