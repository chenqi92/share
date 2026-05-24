import SwiftUI

struct MeTab: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    selfCard
                    AsciiDivider("MANAGE · 管理")
                    actionList
                    AsciiDivider("RECEIVED · 最近收件")
                    pendingCard
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { MeshDropLockup(size: 17) }
            ToolbarItem(placement: .topBarTrailing) {
                IconBtn("gearshape", size: 30, variant: .ghost) { state.showSettings = true }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("我")
                .font(MeshDropFont.display(28, weight: .bold))
            Text("Me.")
                .font(MeshDropFont.display(18, weight: .semibold))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink60)
        }
    }

    private var selfCard: some View {
        HStack(spacing: 14) {
            Avatar(initials: "ME", color: MeshDropColor.lime.opacity(0.9),
                   size: 56, ring: .lime, online: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(Mock.me.name)
                    .font(MeshDropFont.display(20, weight: .bold))
                HStack(spacing: 6) {
                    KindGlyph(.ios, size: 11)
                    Text(Mock.me.os)
                        .font(MeshDropFont.mono(11))
                    Text("·")
                    Text(Mock.me.ip)
                        .font(MeshDropFont.mono(11))
                }
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)

                Text(Mock.me.fingerprint)
                    .font(MeshDropFont.mono(10.5, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.7) : MeshDropColor.ink80)
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding(16)
        .liquidGlass(.rect(18))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var actionList: some View {
        VStack(spacing: 0) {
            actionRow("传输历史", "clock.arrow.circlepath",
                      detail: "6 条今天") { state.showHistory = true }
            divider
            actionRow("信任管理", "checkmark.shield",
                      detail: "5 台已配对") { state.showTrustManager = true }
            divider
            actionRow("配对新设备", "qrcode",
                      detail: "QR / 6 位代码") { state.showPairingSheet = true }
            divider
            actionRow("快速上手", "sparkles",
                      detail: "3 步介绍") { state.showOnboarding = true }
            divider
            actionRow("设置", "gearshape",
                      detail: "可见性 / 加密 / 行为") { state.showSettings = true }
            divider
            actionRow("Share Extension 预览", "square.and.arrow.up",
                      detail: "拦截系统 share sheet") { state.showShareExt = true }
            divider
            actionRow("Live Activity 预览", "clock.badge",
                      detail: "锁屏 + 灵动岛 进度") { state.showLiveActivity = true }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func actionRow(_ title: String, _ icon: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                    .frame(width: 28)
                Text(title)
                    .font(MeshDropFont.body(14.5, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                Spacer()
                Text(detail)
                    .font(MeshDropFont.mono(11))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.35) : MeshDropColor.ink30)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line)
            .frame(height: 0.5)
            .padding(.leading, 54)
    }

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Chip("OFFER", tone: .flame, mono: true, uppercased: true)
                Text("来自 \(Mock.pendingOffer.peer)")
                    .font(MeshDropFont.body(13, weight: .semibold))
                Spacer()
                Text(Mock.pendingOffer.receivedAt)
                    .font(MeshDropFont.mono(10))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
            }
            FileChip(name: Mock.pendingOffer.fileName,
                     size: Mock.pendingOffer.fileSize,
                     ext: "pages")
            if let note = Mock.pendingOffer.note {
                Text("便签：\(note)")
                    .font(MeshDropFont.body(12.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.7) : MeshDropColor.ink80)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(scheme == .dark ? MeshDropColor.lime.opacity(0.10) : MeshDropColor.lime.opacity(0.32))
                    )
            }
            HStack(spacing: 8) {
                Button { state.showOfferSheet = true } label: {
                    Text("查看并选择")
                        .font(MeshDropFont.body(13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Capsule().fill(MeshDropColor.lime))
                        .foregroundStyle(MeshDropColor.ink)
                }
                .buttonStyle(.plain)
                Button {} label: {
                    Text("拒绝")
                        .font(MeshDropFont.body(13, weight: .semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .overlay(Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }
}
