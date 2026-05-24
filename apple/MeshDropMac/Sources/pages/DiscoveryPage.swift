import SwiftUI

struct DiscoveryPage: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                // 标题区
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("附近 5 台设备")
                            .font(MeshDropFont.hero(34))
                            .tracking(-1)
                            .foregroundStyle(MeshDropColor.textPrimary)
                        Text("· Nearby")
                            .font(MeshDropFont.hero(34))
                            .tracking(-1)
                            .foregroundStyle(MeshDropColor.textMuted)
                        Spacer()
                        Chip(text: "E2E · X25519", tone: .lime, mono: true)
                        Chip(text: "LAN ONLY",    tone: .outline, mono: true)
                    }
                    HStack(spacing: 6) {
                        Text("⟳")
                            .font(MeshDropFont.mono(size: 12, weight: .bold))
                            .foregroundStyle(MeshDropColor.limeDeep)
                        Text("扫描中 · scanning LAN · 192.168.1.0/24 · mDNS+uTP")
                            .font(MeshDropFont.mono(size: 11))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                }

                // 主网格：左 stats + 右 radar
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        statBlock(label: "ONLINE",   value: "5", color: MeshDropColor.limeDeep)
                        statBlock(label: "BUSY",     value: "0", color: MeshDropColor.flame)
                        statBlock(label: "OFFLINE",  value: "2", color: MeshDropColor.ink45)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("快速操作")
                                .font(MeshDropFont.body(size: 11, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textMuted)
                            quickAction(text: "复制至所有设备", shortcut: "⌥⇧V")
                            quickAction(text: "发送文字便签",   shortcut: "⌥⇧N")
                            quickAction(text: "广播文件",       shortcut: "⌥⇧S")
                            quickAction(text: "配对新设备",     shortcut: "⌥⇧P")
                        }
                    }
                    .frame(width: 220)

                    VStack(spacing: 0) {
                        Radar(devices: MockDevice.all,
                              variant: .sweep,
                              selectedDeviceID: state.selectedDeviceID,
                              staticTime: 1.4)
                            .frame(height: 460)

                        HStack(spacing: 8) {
                            Text("⤓")
                                .font(MeshDropFont.mono(size: 13, weight: .bold))
                                .foregroundStyle(MeshDropColor.limeDeep)
                            Text("拖任何文件到设备头像即可发送")
                                .font(MeshDropFont.body(size: 12))
                                .foregroundStyle(MeshDropColor.textSecondary)
                            Text("· drag a file to a device avatar")
                                .font(MeshDropFont.body(size: 12))
                                .foregroundStyle(MeshDropColor.textMuted)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(MeshDropColor.cardBg)
                        )
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(MeshDropColor.cardBg)
                            .shadow(color: MeshDropColor.ink06, radius: 6, x: 0, y: 2)
                    )
                }

                AsciiDivider(text: "TODAY · 今天 · 5 件")

                // 今日活动
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(MockHistory.all.prefix(4)) { h in
                        historyCardCompact(h)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .padding(.leading, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    @ViewBuilder
    private func statBlock(label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label)
                .meshTag()
                .foregroundStyle(MeshDropColor.textSecondary)
            Spacer()
            Text(value)
                .font(MeshDropFont.display(size: 26, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeshDropColor.cardBg)
                .shadow(color: MeshDropColor.ink06, radius: 3, x: 0, y: 1)
        )
    }

    @ViewBuilder
    private func quickAction(text: String, shortcut: String) -> some View {
        HStack {
            Text(text)
                .font(MeshDropFont.body(size: 12))
                .foregroundStyle(MeshDropColor.textPrimary)
            Spacer()
            Text(shortcut)
                .font(MeshDropFont.mono(size: 10))
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
                .fill(MeshDropColor.cardBg)
        )
    }

    @ViewBuilder
    private func historyCardCompact(_ h: MockHistory) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(h.dir == .outgoing ? MeshDropColor.flame.opacity(0.12)
                                              : MeshDropColor.sky.opacity(0.12))
                    .frame(width: 34, height: 34)
                Text(h.dir == .outgoing ? "↑" : "↓")
                    .font(MeshDropFont.mono(size: 16, weight: .bold))
                    .foregroundStyle(h.dir == .outgoing ? MeshDropColor.flame : MeshDropColor.sky)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(historyLine(h))
                    .font(MeshDropFont.body(size: 12.5, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 4) {
                    Text(h.peer)
                        .font(MeshDropFont.mono(size: 10))
                        .foregroundStyle(MeshDropColor.textMuted)
                    Text("·").foregroundStyle(MeshDropColor.textMuted)
                    Text(h.time)
                        .font(MeshDropFont.mono(size: 10))
                        .foregroundStyle(MeshDropColor.textMuted)
                }
            }
            Spacer(minLength: 0)
            statusBadge(h.status)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(MeshDropColor.cardBg)
        )
    }

    private func historyLine(_ h: MockHistory) -> String {
        switch h.kind {
        case .text:  return h.content ?? ""
        case .file:  return h.name ?? ""
        case .image: return "\(h.count ?? 0) 张图片"
        }
    }

    @ViewBuilder
    private func statusBadge(_ s: HistoryStatus) -> some View {
        switch s {
        case .done:         Chip(text: "DONE",    tone: .lime,    mono: true)
        case .transferring: Chip(text: "GOING…", tone: .flame,   mono: true)
        case .queued:       Chip(text: "QUEUED",  tone: .outline, mono: true)
        case .failed:       Chip(text: "FAILED",  tone: .flame,   mono: true)
        }
    }
}
