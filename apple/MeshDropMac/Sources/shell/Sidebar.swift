import SwiftUI

/// 搜索 ⌘K + Nearby 列表 + 剪贴板同步卡片 + "本机"。
struct Sidebar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            // logo + 搜索
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Spacer().frame(width: 56)   // 给 traffic lights 让位
                    MeshDropLockup(size: 20)
                    Spacer()
                }
                .padding(.top, 10)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(MeshDropColor.textMuted)
                    Text(state.searchQuery.isEmpty ? "搜索 · Search" : state.searchQuery)
                        .font(MeshDropFont.body(size: 12))
                        .foregroundStyle(state.searchQuery.isEmpty
                                         ? MeshDropColor.textMuted
                                         : MeshDropColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("⌘K")
                        .font(MeshDropFont.mono(size: 10, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(MeshDropColor.divider, lineWidth: 0.5)
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MeshDropColor.cardBg2)
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)

            // 主导航
            navItem(.discovery, title: "附近 · Nearby", badge: "5", system: "antenna.radiowaves.left.and.right")
            navItem(.chat,       title: "对话 · Chat",      badge: "3", system: "bubble.left.and.bubble.right")
            navItem(.transfers,  title: "传输 · Transfers", badge: "2", system: "arrow.up.arrow.down")
            navItem(.history,    title: "历史 · History",   badge: "12", system: "clock.arrow.circlepath")
            navItem(.clipboard,  title: "剪贴板 · Clipboard", badge: "5", system: "doc.on.clipboard")
            navItem(.trust,      title: "已配对 · Paired",  badge: nil,  system: "person.2.badge.key")
            navItem(.settings,   title: "设置 · Settings",  badge: nil,  system: "gearshape")

            // 附近 device cards
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("● 附近 · Nearby")
                        .font(MeshDropFont.body(size: 11, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textSecondary)
                    Spacer()
                    Text("5")
                        .font(MeshDropFont.mono(size: 10))
                        .foregroundStyle(MeshDropColor.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)

                ForEach(MockDevice.all) { dev in
                    DeviceCard(device: dev, selected: dev.id == state.selectedDeviceID)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                        .onTapGesture {
                            state.selectedDeviceID = dev.id
                            state.tab = .chat
                        }
                }
            }

            // 剪贴板同步卡片
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("剪贴板已同步")
                        .font(MeshDropFont.body(size: 11, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textSecondary)
                    Spacer()
                    Text("⌘V")
                        .font(MeshDropFont.mono(size: 9, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(MeshDropColor.divider, lineWidth: 0.5)
                        )
                }
                Text(MockClip.all[0].body)
                    .font(MeshDropFont.mono(size: 11))
                    .foregroundStyle(MeshDropColor.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text("from \(MockClip.all[0].who) · 8s ago")
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(MeshDropColor.limeFill)
            )
            .padding(.horizontal, 12)
            .padding(.top, 14)

            Spacer(minLength: 12)

            // 本机
            HStack(spacing: 10) {
                Avatar(initials: "我", color: Color(hex: 0xE2DCCD), size: 32, ring: true, ringColor: MeshDropColor.lime)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(state.displayName)")
                        .font(MeshDropFont.body(size: 12.5, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text(MockMe.visibility)
                        .font(MeshDropFont.mono(size: 9.5))
                        .foregroundStyle(MeshDropColor.limeDeep)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(MeshDropColor.cardBg)
                    .shadow(color: MeshDropColor.ink06, radius: 2, x: 0, y: -1)
            )
        }
        .frame(width: 280)
        .background(MeshDropColor.glassBg)
        .overlay(
            Rectangle()
                .frame(width: 1)
                .foregroundStyle(MeshDropColor.divider),
            alignment: .trailing
        )
    }

    @ViewBuilder
    private func navItem(_ tab: MainTab, title: String, badge: String?, system: String) -> some View {
        let active = state.tab == tab
        HStack(spacing: 10) {
            Image(systemName: system)
                .font(.system(size: 12))
                .foregroundStyle(active ? MeshDropColor.ink : MeshDropColor.textSecondary)
                .frame(width: 16)
            Text(title)
                .font(MeshDropFont.body(size: 12.5, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? MeshDropColor.ink : MeshDropColor.textPrimary)
            Spacer()
            if let badge {
                Text(badge)
                    .font(MeshDropFont.mono(size: 10, weight: .semibold))
                    .foregroundStyle(active ? MeshDropColor.ink : MeshDropColor.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(active ? MeshDropColor.lime.opacity(0.4) : MeshDropColor.cardBg2)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? MeshDropColor.limeFill : .clear)
                .padding(.horizontal, 8)
        )
        .contentShape(Rectangle())
        .onTapGesture { state.tab = tab }
    }
}
