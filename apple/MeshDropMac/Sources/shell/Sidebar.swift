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
            let devicesCount = state.engineDevices.count
            let activeTransfers = state.engineHistory.filter { $0.status == .transferring }.count
            let pendingBadge = (state.enginePairing != nil ? 1 : 0) + (state.engineOffer != nil ? 1 : 0)
            navItem(.discovery, title: "附近 · Nearby",
                    badge: devicesCount > 0 ? "\(devicesCount)" : nil,
                    system: "antenna.radiowaves.left.and.right")
            navItem(.chat,       title: "对话 · Chat",      badge: nil, system: "bubble.left.and.bubble.right")
            navItem(.transfers,  title: "传输 · Transfers",
                    badge: activeTransfers > 0 ? "\(activeTransfers)" : nil,
                    system: "arrow.up.arrow.down")
            navItem(.history,    title: "历史 · History",
                    badge: state.engineHistory.isEmpty ? nil : "\(state.engineHistory.count)",
                    system: "clock.arrow.circlepath")
            navItem(.clipboard,  title: "剪贴板 · Clipboard", badge: nil, system: "doc.on.clipboard")
            navItem(.trust,      title: "已配对 · Paired",
                    badge: pendingBadge > 0 ? "\(pendingBadge)" : nil,
                    system: "person.2.badge.key")
            navItem(.settings,   title: "设置 · Settings",  badge: nil,  system: "gearshape")

            // 附近 device cards
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("● 附近 · Nearby")
                        .font(MeshDropFont.body(size: 11, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textSecondary)
                    Spacer()
                    Text("\(state.engineDevices.count)")
                        .font(MeshDropFont.mono(size: 10))
                        .foregroundStyle(MeshDropColor.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)

                if state.engineDevices.isEmpty {
                    VStack(spacing: 4) {
                        Text(state.isScanning ? "扫描中 · scanning…" : "附近暂无设备")
                            .font(MeshDropFont.mono(size: 11))
                            .foregroundStyle(MeshDropColor.textMuted)
                        Text("让朋友也打开 MeshDrop 试试")
                            .font(MeshDropFont.body(size: 11))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                } else {
                    ForEach(state.engineDevices) { dev in
                        DeviceCard(device: dev, selected: dev.id == state.selectedDeviceID)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 1)
                            .onTapGesture {
                                state.selectedDeviceID = dev.id
                                state.tab = .chat
                            }
                    }
                }
            }

            Spacer(minLength: 12)

            // 本机
            HStack(spacing: 10) {
                Avatar(initials: "我", color: Color(hex: 0xE2DCCD), size: 32, ring: true, ringColor: MeshDropColor.lime)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(state.displayName)")
                        .font(MeshDropFont.body(size: 12.5, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text(state.isScanning ? "扫描中 · scanning LAN" : "可见 · Visible · LAN")
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
