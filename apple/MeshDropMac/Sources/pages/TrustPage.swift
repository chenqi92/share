import SwiftUI

struct TrustPage: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("已配对")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("· Trust Manager")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                    Chip(text: "Ed25519 指纹", tone: .lime, mono: true)
                    Chip(text: "+ 配对新设备 ⌥⇧P", tone: .outline, mono: false)
                }
                Text("已与本机配对的设备会在此显示。指纹（fingerprint）应与对端目视核对一致才能信任。")
                    .font(MeshDropFont.body(size: 12))
                    .foregroundStyle(MeshDropColor.textSecondary)

                AsciiDivider(text: "PAIRED · 已配对 · \(state.engineTrusted.count) 台")

                if state.engineTrusted.isEmpty {
                    Text("还没有已配对的设备。和别人互发第一份内容会触发配对。")
                        .font(MeshDropFont.body(size: 12))
                        .foregroundStyle(MeshDropColor.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(MeshDropColor.cardBg)
                        )
                } else {
                    tableHeader

                    VStack(spacing: 0) {
                        ForEach(Array(state.engineTrusted.enumerated()), id: \.element.id) { i, t in
                            row(t)
                            if i < state.engineTrusted.count - 1 {
                                Rectangle()
                                    .fill(MeshDropColor.divider)
                                    .frame(height: 1)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(MeshDropColor.cardBg)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            cell("设备 · DEVICE", width: 240)
            cell("指纹 · FINGERPRINT (Ed25519)", width: 280)
            cell("配对日期",                    width: 110)
            cell("最近在线",                    width: 110)
            cell("",                            width: 100)
        }
        .font(MeshDropFont.divider(10))
        .textCase(.uppercase)
        .tracking(1.4)
        .foregroundStyle(MeshDropColor.textMuted)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cell(_ s: String, width: CGFloat) -> some View {
        Text(s)
            .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func row(_ t: MockTrustedDevice) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                Avatar(initials: String(t.who.prefix(2)),
                       color: avatar(for: t.kind),
                       size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t.name)
                        .font(MeshDropFont.body(size: 12.5, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    HStack(spacing: 5) {
                        KindGlyph(kind: t.kind, size: 10)
                        Text(t.who)
                            .font(MeshDropFont.mono(size: 10))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                }
            }
            .frame(width: 240, alignment: .leading)

            Text(t.fingerprint)
                .font(MeshDropFont.mono(size: 10.5))
                .foregroundStyle(MeshDropColor.textSecondary)
                .frame(width: 280, alignment: .leading)

            Text(t.pairedAt)
                .font(MeshDropFont.mono(size: 11))
                .foregroundStyle(MeshDropColor.textMuted)
                .frame(width: 110, alignment: .leading)

            HStack(spacing: 5) {
                Circle().fill(t.online ? MeshDropColor.limeDeep : MeshDropColor.ink45).frame(width: 5, height: 5)
                Text(t.lastSeen)
                    .font(MeshDropFont.mono(size: 11))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            .frame(width: 110, alignment: .leading)

            Button { state.revokeTrust(fingerprint: t.id) } label: {
                Text("撤销 · Revoke")
                    .font(MeshDropFont.body(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(MeshDropColor.error, lineWidth: 1)
                    )
                    .foregroundStyle(MeshDropColor.error)
            }
            .buttonStyle(.plain)
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
    }

    private func avatar(for kind: DeviceKind) -> Color {
        switch kind {
        case .mac:     return Color(hex: 0xFFB4A1)
        case .ios:     return Color(hex: 0xFFD970)
        case .ipad:    return Color(hex: 0xC7B8FF)
        case .android: return Color(hex: 0xB7E5C8)
        case .win:     return Color(hex: 0x9AD0FF)
        }
    }
}
