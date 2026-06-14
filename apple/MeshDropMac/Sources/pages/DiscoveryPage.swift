import SwiftUI

struct DiscoveryPage: View {
    @EnvironmentObject var state: AppState
    private var screenshotTime: Double? {
        ProcessInfo.processInfo.environment["MESHDROP_SCREENSHOT"] == "1" ? 1.4 : nil
    }

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                // 标题区
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("附近 \(state.engineDevices.count) 台设备")
                            .font(MeshDropFont.hero(34))
                            .tracking(-1)
                            .foregroundStyle(MeshDropColor.textPrimary)
                        Text("· Nearby")
                            .font(MeshDropFont.hero(34))
                            .tracking(-1)
                            .foregroundStyle(MeshDropColor.textMuted)
                        Spacer()
                        Chip(text: "LAN · 明文 · v0.1", tone: .outline, mono: true)
                        Chip(text: "LAN ONLY",         tone: .outline, mono: true)
                    }
                    HStack(spacing: 6) {
                        Text("⟳")
                            .font(MeshDropFont.mono(size: 12, weight: .bold))
                            .foregroundStyle(state.isScanning ? MeshDropColor.flame : MeshDropColor.limeDeep)
                        Text(state.isScanning
                             ? "扫描中 · scanning LAN · \(state.localIPSummary) · mDNS"
                             : "已就绪 · ready · \(state.localIPSummary) · mDNS+uTP")
                            .font(MeshDropFont.mono(size: 11))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                    if let err = state.lastError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(MeshDropColor.error)
                            Text("网络出错 — \(err)")
                                .font(MeshDropFont.body(size: 11.5))
                                .foregroundStyle(MeshDropColor.error)
                            Spacer()
                            Text("关闭")
                                .font(MeshDropFont.body(size: 11, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textSecondary)
                                .onTapGesture { state.clearError() }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(MeshDropColor.error.opacity(0.08))
                        )
                    }
                }

                // 主网格：左 stats + 右 radar
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 14) {
                        statBlock(label: "ONLINE",   value: "\(state.engineDevices.filter { $0.online }.count)", color: MeshDropColor.limeDeep)
                        statBlock(label: "TRUSTED",  value: "\(state.engineTrusted.count)", color: MeshDropColor.flame)
                        statBlock(label: "PENDING",  value: "\((state.enginePairing != nil ? 1 : 0) + (state.engineOffer != nil ? 1 : 0))", color: MeshDropColor.ink45)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("快速操作")
                                .font(MeshDropFont.body(size: 11, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textMuted)
                            quickAction(text: "剪贴板同步") { state.tab = .clipboard }
                            quickAction(text: "发送文字便签") { state.tab = .chat }
                            quickAction(text: "查看传输") { state.tab = .transfers }
                            quickAction(text: "配对新设备") { state.tab = .pairing }
                        }
                    }
                    .frame(width: 220)

                    VStack(spacing: 0) {
                        if state.engineDevices.isEmpty {
                            emptyDeviceCard
                                .frame(height: 460)
                        } else {
                            Radar(devices: state.engineDevices,
                                  variant: .sweep,
                                  selectedDeviceID: state.selectedDeviceID,
                                  staticTime: screenshotTime)
                                .frame(height: 460)
                        }

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

                AsciiDivider(text: "TODAY · 今天 · \(state.engineHistory.count) 件")

                // 今日活动
                if state.engineHistory.isEmpty {
                    emptyHistoryCard
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(state.engineHistory.prefix(4)) { h in
                            historyCardCompact(h)
                        }
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

    private var emptyDeviceCard: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(MeshDropColor.textMuted)
            Text("附近没有 MeshDrop 设备")
                .font(MeshDropFont.body(size: 14, weight: .semibold))
                .foregroundStyle(MeshDropColor.textPrimary)
            Text("让朋友也打开 MeshDrop · 同一 Wi-Fi 即可")
                .font(MeshDropFont.body(size: 12))
                .foregroundStyle(MeshDropColor.textMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyHistoryCard: some View {
        VStack(spacing: 6) {
            Text("还没有传输记录")
                .font(MeshDropFont.body(size: 12.5, weight: .semibold))
                .foregroundStyle(MeshDropColor.textSecondary)
            Text("发出去 / 收到的第一份内容会显示在这里")
                .font(MeshDropFont.body(size: 11))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeshDropColor.cardBg)
        )
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
    private func quickAction(text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(MeshDropFont.body(size: 12))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(MeshDropColor.cardBg)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
