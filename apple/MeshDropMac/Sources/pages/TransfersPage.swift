import SwiftUI
import MeshDropKit

struct TransfersPage: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(alignment: .top, spacing: 14) {
                    SpeedChart(bars: displayBars(state.uploadBars, mock: { MockSpeed.uploadBars }),
                               color: MeshDropColor.flame,
                               title: String(localized: "transfers.chart.up"),
                               subtitle: Self.formatSpeed(state.currentUploadBps),
                               arrow: "↑")
                        .frame(maxWidth: .infinity)
                    SpeedChart(bars: displayBars(state.downloadBars, mock: { MockSpeed.downloadBars }),
                               color: MeshDropColor.sky,
                               title: String(localized: "transfers.chart.down"),
                               subtitle: Self.formatSpeed(state.currentDownloadBps),
                               arrow: "↓")
                        .frame(maxWidth: .infinity)
                    sessionTotal
                        .frame(width: 220)
                }

                let transfers = engineTransfers
                AsciiDivider(text: String(format: String(localized: "transfers.divider.tasks"),
                                          transfers.count,
                                          transfers.filter { $0.state == .sending || $0.state == .receiving }.count,
                                          transfers.filter { $0.state == .done }.count))

                if transfers.isEmpty {
                    emptyView
                } else {
                    VStack(spacing: 10) {
                        ForEach(transfers) { item in
                            TransferRow(
                                item: item,
                                onCancel: { state.cancelTransfer(item.id) },
                                onRetry: item.from == String(localized: "common.me") ? { state.retryTransfer(item.id) } : nil,
                                savedURL: savedURL(for: item),
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    /// 速度柱状数据源：优先用 engine 实时采样；为空时 release 渲染空态，
    /// 仅 DEBUG（Preview / 离线截图）回退到 MockSpeed 假序列。
    private func displayBars(_ live: [Int], mock: () -> [Int]) -> [Int] {
        if !live.isEmpty { return live }
        #if DEBUG
        return mock()
        #else
        return []
        #endif
    }

    /// 把 engineHistory 中的文件项投影成 MockTransfer，供 TransferRow 复用。
    /// `id` 字段携带真实 history.id，让 TransferRow 的取消按钮能精确定位 ctx。
    private var engineTransfers: [MockTransfer] {
        state.engineHistory.compactMap { h in
            guard h.kind == .file, let name = h.name, let size = h.size else { return nil }
            // "我" 既作显示也作内部 from/to 比较标记，统一走 common.me 保证两端一致
            let me = String(localized: "common.me")
            let fromTo: (from: String, to: String) = h.dir == .outgoing
                ? (me, h.peer)
                : (h.peer, me)
            let prog = h.progress ?? 0
            let st: TransferState
            switch h.status {
            case .done: st = .done
            case .transferring: st = h.dir == .outgoing ? .sending : .receiving
            case .queued: st = .queued
            case .failed: st = .failed
            }
            let metrics = UUID(uuidString: h.id).flatMap { state.transferMetrics[$0] }
            let speed: String? = {
                guard st == .sending || st == .receiving, let m = metrics, m.bytesPerSec > 1 else { return nil }
                return "\(Self.byteFormatter.string(fromByteCount: Int64(m.bytesPerSec)))/s"
            }()
            let eta: String? = {
                guard st == .sending || st == .receiving, let secs = metrics?.etaSeconds else { return nil }
                return Self.formatEta(secs)
            }()
            let failReason: String? = {
                guard st == .failed,
                      let uuid = UUID(uuidString: h.id),
                      let item = state.engineHistoryItems.first(where: { $0.id == uuid }) else { return nil }
                if case .failed(let reason) = item.status { return reason }
                if case .canceled = item.status { return String(localized: "common.canceled") }
                return nil
            }()
            return MockTransfer(
                id: UUID(uuidString: h.id) ?? UUID(),
                name: name,
                size: size,
                ext: h.ext ?? "bin",
                from: fromTo.from,
                to: fromTo.to,
                progress: prog,
                state: st,
                speed: speed,
                eta: eta,
                failReason: failReason
            )
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    private static func formatEta(_ secs: Double) -> String {
        if !secs.isFinite || secs < 0 { return "—" }
        if secs < 1 { return "<1s" }
        if secs >= 3600 { return ">1h" }
        let s = Int(secs.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    /// 速率小标题（SpeedChart subtitle）：bytes/sec → "8.4 MB/s"，0 时返回 "—"。
    private static func formatSpeed(_ bps: Double) -> String {
        guard bps > 1 else { return "—" }
        return "\(byteFormatter.string(fromByteCount: Int64(bps)))/s"
    }

    /// 已完成接收项的本地保存路径 —— 给 TransferRow 的 Reveal / Open 按钮用。
    /// 仅对 done && incoming && kind=.file 的项返回 URL；其余返回 nil。
    private func savedURL(for transfer: MockTransfer) -> URL? {
        guard transfer.state == .done, transfer.to == String(localized: "common.me") else { return nil }
        guard let item = state.engineHistoryItems.first(where: { $0.id == transfer.id }),
              case .file(_, _, let url) = item.kind else { return nil }
        return url
    }

    /// 会话总计：(num, unit) 拆开方便 UI 用不同字号渲染。
    private static func formatTotal(_ bytes: UInt64) -> (String, String) {
        if bytes == 0 { return ("0", "B") }
        let kb = Double(bytes) / 1024
        if kb < 1024 { return (String(format: "%.1f", kb), "KB") }
        let mb = kb / 1024
        if mb < 1024 { return (String(format: "%.1f", mb), "MB") }
        let gb = mb / 1024
        return (String(format: "%.2f", gb), "GB")
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(MeshDropColor.textMuted)
            Text("transfers.empty.title")
                .font(MeshDropFont.body(size: 14, weight: .semibold))
                .foregroundStyle(MeshDropColor.textPrimary)
            Text("transfers.empty.detail")
                .font(MeshDropFont.body(size: 12))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(MeshDropColor.cardBg)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            let transfers = engineTransfers
            HStack {
                Text("transfers.title")
                    .font(MeshDropFont.hero(34))
                    .tracking(-1)
                    .foregroundStyle(MeshDropColor.textPrimary)
                Text("transfers.title.suffix")
                    .font(MeshDropFont.hero(34))
                    .tracking(-1)
                    .foregroundStyle(MeshDropColor.textMuted)
                Spacer()
                filterChip(text: String(localized: "transfers.filter.all"), count: transfers.count, active: state.transferFilter == nil) { state.transferFilter = nil }
                filterChip(text: String(localized: "transfers.filter.active"), count: transfers.filter { $0.state == .sending || $0.state == .receiving }.count, active: state.transferFilter == .sending) { state.transferFilter = .sending }
                filterChip(text: String(localized: "transfers.filter.done"), count: transfers.filter { $0.state == .done }.count, active: state.transferFilter == .done) { state.transferFilter = .done }
                filterChip(text: String(localized: "transfers.filter.failed"),   count: transfers.filter { $0.state == .failed }.count, active: state.transferFilter == .failed) { state.transferFilter = .failed }
            }
            HStack(spacing: 8) {
                Text(String(format: String(localized: "transfers.summary"),
                            transfers.count,
                            transfers.filter { $0.state == .sending || $0.state == .receiving }.count,
                            transfers.filter { $0.state == .done }.count))
                    .font(MeshDropFont.mono(size: 11))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
        }
    }

    @ViewBuilder
    private func filterChip(text: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text == "全部" ? text : "\(text) · \(count)")
                .font(MeshDropFont.body(size: 11, weight: .semibold))
                .tracking(0.1)
                .padding(.horizontal, 8)
                .frame(height: 20)
            .background(
                Capsule(style: .continuous)
                    .fill(active ? MeshDropColor.outgoingBubble : Color.clear)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(active ? Color.clear : MeshDropColor.ink12, lineWidth: 1)
            )
            .foregroundStyle(active ? (scheme == .dark ? MeshDropColor.ink : MeshDropColor.paper) : MeshDropColor.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var sessionTotal: some View {
        let total = state.sessionUploadBytes + state.sessionDownloadBytes
        let (num, unit) = Self.formatTotal(total)
        return VStack(alignment: .leading, spacing: 8) {
            Text("transfers.sessionTotal")
                .meshTag()
                .foregroundStyle(MeshDropColor.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(num)
                    .font(MeshDropFont.display(size: 36, weight: .bold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Text(unit)
                    .font(MeshDropFont.mono(size: 13, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            GeometryReader { geo in
                let bars = displayBars(state.sessionBars, mock: { MockSpeed.sessionBars })
                let maxV = max(CGFloat(bars.max() ?? 1), 1)
                let barW = max(2, (geo.size.width - CGFloat(max(bars.count - 1, 0)) * 2) / CGFloat(max(bars.count, 1)))
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                        Capsule()
                            .fill(MeshDropColor.lime)
                            .frame(width: barW,
                                   height: max(2, geo.size.height * CGFloat(v) / maxV))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .bottomLeading)
            }
            .frame(height: 56)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeshDropColor.cardBg)
        )
    }
}
