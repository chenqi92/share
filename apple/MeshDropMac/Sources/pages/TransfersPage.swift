import SwiftUI
import MeshDropKit

struct TransfersPage: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                header

                HStack(alignment: .top, spacing: 14) {
                    SpeedChart(bars: MockSpeed.uploadBars,
                               color: MeshDropColor.flame,
                               title: "上行 · UP",
                               subtitle: "—",
                               arrow: "↑")
                        .frame(maxWidth: .infinity)
                    SpeedChart(bars: MockSpeed.downloadBars,
                               color: MeshDropColor.sky,
                               title: "下行 · DOWN",
                               subtitle: "—",
                               arrow: "↓")
                        .frame(maxWidth: .infinity)
                    sessionTotal
                        .frame(width: 220)
                }

                let transfers = engineTransfers
                AsciiDivider(text: "TASKS · \(transfers.count) 任务 · \(transfers.filter { $0.state == .sending || $0.state == .receiving }.count) 进行 · \(transfers.filter { $0.state == .done }.count) 完成")

                if transfers.isEmpty {
                    emptyView
                } else {
                    VStack(spacing: 10) {
                        ForEach(transfers) { item in
                            TransferRow(
                                item: item,
                                onCancel: { state.cancelTransfer(item.id) },
                                onRetry: item.from == "我" ? { state.retryTransfer(item.id) } : nil,
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

    /// 把 engineHistory 中的文件项投影成 MockTransfer，供 TransferRow 复用。
    /// `id` 字段携带真实 history.id，让 TransferRow 的取消按钮能精确定位 ctx。
    private var engineTransfers: [MockTransfer] {
        state.engineHistory.compactMap { h in
            guard h.kind == .file, let name = h.name, let size = h.size else { return nil }
            let fromTo: (from: String, to: String) = h.dir == .outgoing
                ? ("我", h.peer)
                : (h.peer, "我")
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
                eta: eta
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

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(MeshDropColor.textMuted)
            Text("当前没有传输")
                .font(MeshDropFont.body(size: 14, weight: .semibold))
                .foregroundStyle(MeshDropColor.textPrimary)
            Text("拖文件到设备头像即可开始")
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
                Text("传输")
                    .font(MeshDropFont.hero(34))
                    .tracking(-1)
                    .foregroundStyle(MeshDropColor.textPrimary)
                Text("· Transfers")
                    .font(MeshDropFont.hero(34))
                    .tracking(-1)
                    .foregroundStyle(MeshDropColor.textMuted)
                Spacer()
                filterChip(text: "全部", count: transfers.count, active: state.transferFilter == nil) { state.transferFilter = nil }
                filterChip(text: "进行中", count: transfers.filter { $0.state == .sending || $0.state == .receiving }.count, active: state.transferFilter == .sending) { state.transferFilter = .sending }
                filterChip(text: "已完成", count: transfers.filter { $0.state == .done }.count, active: state.transferFilter == .done) { state.transferFilter = .done }
                filterChip(text: "失败",   count: transfers.filter { $0.state == .failed }.count, active: state.transferFilter == .failed) { state.transferFilter = .failed }
            }
            HStack(spacing: 8) {
                Text("\(transfers.count) 个任务 · \(transfers.filter { $0.state == .sending || $0.state == .receiving }.count) 进行中 · \(transfers.filter { $0.state == .done }.count) 已完成")
                    .font(MeshDropFont.mono(size: 11))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
        }
    }

    @ViewBuilder
    private func filterChip(text: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(text)
                    .font(MeshDropFont.body(size: 12, weight: .semibold))
                Text("\(count)")
                    .font(MeshDropFont.mono(size: 11, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(MeshDropColor.divider)
                    )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 999)
                    .fill(active ? MeshDropColor.lime : MeshDropColor.cardBg2)
            )
            .foregroundStyle(active ? MeshDropColor.ink : MeshDropColor.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var sessionTotal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本会话总计")
                .meshTag()
                .foregroundStyle(MeshDropColor.textMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("2.41")
                    .font(MeshDropFont.display(size: 36, weight: .bold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Text("GB")
                    .font(MeshDropFont.mono(size: 13, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            GeometryReader { geo in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(MockSpeed.sessionBars.enumerated()), id: \.offset) { _, v in
                        Capsule()
                            .fill(MeshDropColor.lime)
                            .frame(width: (geo.size.width - 14 * 2) / 15,
                                   height: max(2, CGFloat(v) * 3.5))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
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
