import SwiftUI

/// 上 / 下行速度条形图。每根条对应一个时间槽，bar 圆角、上下行颜色不同。
struct SpeedChart: View {
    let bars: [Int]
    let color: Color
    var title: String
    var subtitle: String
    var arrow: String         // "↑" 或 "↓"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(arrow)
                    .font(MeshDropFont.mono(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Text(title)
                    .font(MeshDropFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Spacer()
                Text(subtitle)
                    .font(MeshDropFont.mono(size: 11))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            GeometryReader { geo in
                if bars.isEmpty {
                    // 无实时采样时渲染空态基线，不回退到假数据。
                    HStack {
                        Text("暂无数据 · NO DATA")
                            .font(MeshDropFont.mono(size: 10))
                            .foregroundStyle(MeshDropColor.textMuted)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                } else {
                    let maxV = max(CGFloat(bars.max() ?? 1), 1)
                    let barW = (geo.size.width - CGFloat(bars.count - 1) * 3) / CGFloat(bars.count)
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(Array(bars.enumerated()), id: \.offset) { _, v in
                            Capsule()
                                .fill(color)
                                .frame(width: barW, height: max(2, geo.size.height * CGFloat(v) / maxV))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .bottomLeading)
                }
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
