import SwiftUI

/// MeshDrop 标准磨砂玻璃面板。
/// visionOS 自带的 `.glassBackgroundEffect()` 已经完成 80px blur + saturate 180% 的实装；
/// 这里再叠一层很薄的 tint + 内描边 highlight，让面板看起来"轻轻浮在空间里"。
struct GlassCard<Content: View>: View {
    var corner: CGFloat = 28
    var tint: Color = MD.glassTint
    var stroke: Color = MD.glassStroke
    var innerHighlight: Color = MD.glassStrokeHi
    /// 给传输页等需要"超薄玻璃"的卡片：tint 变得更暗，less opaque
    var bare: Bool = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background(
                ZStack {
                    // 当 visionOS 实玻璃叠加进来后，下面这层主要起 tint 作用。
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(bare ? MD.glassFloorTint : tint)
                    // 内层 highlight：营造"玻璃顶部高光 inset 1px"。
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(innerHighlight.opacity(0.65), lineWidth: 0.6)
                        .blendMode(.overlay)
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(stroke, lineWidth: 0.9)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

/// ASCII Divider（COMMON §7.12）。`── TODAY · 今天 · 5 件 ──`
struct ASCIIDivider: View {
    let label: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 0.6)
            Text(label)
                .font(MDFont.divider)
                .mdDividerLabel()
                .foregroundStyle(MD.dpaper.opacity(0.45))
                .fixedSize()
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 0.6)
        }
    }
}
