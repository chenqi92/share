import SwiftUI
import MeshDropKit

/// 中央磨砂玻璃面板：hero copy + 实时设备计数 + 操作提示。
/// Spatial 端没有"已选 payload"概念（visionOS 走 fileImporter 即时选择），
/// 把原来的 selected payload block 改成了"最近一次互动"摘要。
struct MainWindow: View {
    @EnvironmentObject private var engine: ShareEngine

    var body: some View {
        GlassCard(corner: 38) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                    .overlay(MD.dline)
                    .padding(.vertical, 18)
                heroCopy
                Spacer().frame(height: 26)
                recentActivityBlock
                Spacer()
                gazePinchHint
            }
            .padding(.horizontal, 36)
            .padding(.top, 28)
            .padding(.bottom, 28)
            .frame(width: 580, height: 540, alignment: .topLeading)
        }
    }

    // MARK: head
    private var header: some View {
        HStack(spacing: 14) {
            MeshDropLockup(size: 26)
            Chip(text: "SPATIAL · 客厅", tone: .outline, mono: true)
            Spacer()
            if engine.isStarting {
                Chip(text: "● SCANNING", tone: .outline, mono: true)
            } else if engine.devices.isEmpty {
                Chip(text: "● 等待设备", tone: .outline, mono: true)
            } else {
                Chip(text: "● \(engine.devices.count) PEERS", tone: .lime, mono: true)
            }
        }
    }

    // MARK: hero copy
    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            if engine.isStarting {
                Text("正在扫描")
                    .font(MDFont.hero)
                    .foregroundStyle(MD.dpaper)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("你身边的设备…")
                        .font(MDFont.hero)
                        .foregroundStyle(MD.lime)
                }
                Text("SCANNING · mDNS · _meshdrop._tcp")
                    .font(MDFont.micro).mdMonoTracking()
                    .foregroundStyle(MD.dpaper.opacity(0.55))
                    .padding(.top, 4)
            } else if engine.devices.isEmpty {
                Text("你身边")
                    .font(MDFont.hero)
                    .foregroundStyle(MD.dpaper)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("还没有设备。")
                        .font(MDFont.hero)
                        .foregroundStyle(MD.flame)
                }
                Text("让朋友也打开 MeshDrop · 同一 Wi-Fi 即可发现")
                    .font(MDFont.body)
                    .foregroundStyle(MD.dpaper.opacity(0.65))
                    .padding(.top, 4)
            } else {
                Text("你身边的设备")
                    .font(MDFont.hero)
                    .foregroundStyle(MD.dpaper)
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text("都已就位。")
                        .font(MDFont.hero)
                        .foregroundStyle(MD.lime)
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MD.dpaper.opacity(0.45))
                }
                Text("看向任意一台设备 · 捏合即发送")
                    .font(MDFont.body)
                    .foregroundStyle(MD.dpaper.opacity(0.65))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: 最近互动
    private var recentActivityBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            ASCIIDivider(label: recentLabel)

            if let recent = engine.history.first {
                HStack(spacing: 12) {
                    let mock = LivePeerMapper.mockDevice(from: recent.peer, index: 0, total: 1)
                    Avatar(initials: mock.initials, color: mock.color, size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(recent.direction == .outgoing ? "→ \(mock.who)" : "← \(mock.who)")
                                .font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
                            Spacer()
                            Text(statusLabel(recent.status))
                                .font(MDFont.microHi).tracking(1.4)
                                .foregroundStyle(statusColor(recent.status))
                        }
                        Text(historySnippet(recent))
                            .font(MDFont.body)
                            .foregroundStyle(MD.dpaper.opacity(0.72))
                            .lineLimit(2)
                    }
                }
            } else {
                Text("EMPTY · 还没有互动")
                    .font(MDFont.micro).mdMonoTracking()
                    .foregroundStyle(MD.dpaper.opacity(0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            }
        }
    }

    private var recentLabel: String {
        let total = engine.history.count
        return "Recent · 最近互动 · 共 \(total) 条"
    }

    private func statusLabel(_ status: TransferStatus) -> String {
        switch status {
        case .pending:                return "PENDING"
        case .waitingApproval:        return "等待对方"
        case .transferring(let d, let t) where t > 0:
            return "\(Int(Double(d)/Double(t)*100))%"
        case .transferring:           return "传输中"
        case .completed:              return "DONE"
        case .failed(let msg):        return "FAIL · \(msg.prefix(12))"
        case .canceled:               return "CANCELED"
        }
    }

    private func statusColor(_ status: TransferStatus) -> Color {
        switch status {
        case .completed: return MD.lime
        case .failed:    return MD.flame
        case .canceled:  return MD.dpaper.opacity(0.5)
        default:         return MD.sky
        }
    }

    private func historySnippet(_ item: HistoryItem) -> String {
        switch item.kind {
        case .text(let body): return body
        case .file(let name, let bytes, _):
            let s = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            return "文件 · \(name) · \(s)"
        }
    }

    // MARK: gaze · pinch · 长按 提示行
    private var gazePinchHint: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .semibold))
                Text("GAZE")
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MD.dpaper.opacity(0.35))
            HStack(spacing: 8) {
                Image(systemName: "hand.pinch")
                    .font(.system(size: 11, weight: .semibold))
                Text("PINCH")
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MD.dpaper.opacity(0.35))
            HStack(spacing: 8) {
                Image(systemName: "hand.point.up.left.and.text")
                    .font(.system(size: 11, weight: .semibold))
                Text("HOLD · 上下文")
            }
            Spacer()
            Text("LAN · 明文 · v0.1")
                .font(MDFont.microHi).tracking(1.6).textCase(.uppercase)
                .foregroundStyle(MD.limeDeep)
        }
        .font(MDFont.chipMono)
        .tracking(1.6)
        .textCase(.uppercase)
        .foregroundStyle(MD.dpaper.opacity(0.65))
    }
}
