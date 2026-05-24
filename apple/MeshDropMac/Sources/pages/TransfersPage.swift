import SwiftUI

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
                               subtitle: "8.4 MB/s",
                               arrow: "↑")
                        .frame(maxWidth: .infinity)
                    SpeedChart(bars: MockSpeed.downloadBars,
                               color: MeshDropColor.sky,
                               title: "下行 · DOWN",
                               subtitle: "11.7 MB/s",
                               arrow: "↓")
                        .frame(maxWidth: .infinity)
                    sessionTotal
                        .frame(width: 220)
                }

                AsciiDivider(text: "TASKS · 6 任务 · 2 进行 · 1 排队 · 3 完成")

                VStack(spacing: 10) {
                    ForEach(MockTransfer.all) { item in
                        TransferRow(item: item)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                filterChip(text: "全部", count: 6, active: state.transferFilter == nil) { state.transferFilter = nil }
                filterChip(text: "进行中", count: 2, active: state.transferFilter == .sending) { state.transferFilter = .sending }
                filterChip(text: "已完成", count: 3, active: state.transferFilter == .done) { state.transferFilter = .done }
                filterChip(text: "失败",   count: 0, active: state.transferFilter == .failed) { state.transferFilter = .failed }
            }
            HStack(spacing: 8) {
                Text("6 个任务 · 2 进行中 · 1 排队 · 3 已完成")
                    .font(MeshDropFont.mono(size: 11))
                    .foregroundStyle(MeshDropColor.textMuted)
                Text("·")
                    .foregroundStyle(MeshDropColor.textMuted)
                Text("↑ 11.5 MB/s")
                    .font(MeshDropFont.mono(size: 11, weight: .semibold))
                    .foregroundStyle(MeshDropColor.flame)
                Text("·")
                    .foregroundStyle(MeshDropColor.textMuted)
                Text("↓ 11.7 MB/s")
                    .font(MeshDropFont.mono(size: 11, weight: .semibold))
                    .foregroundStyle(MeshDropColor.sky)
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
