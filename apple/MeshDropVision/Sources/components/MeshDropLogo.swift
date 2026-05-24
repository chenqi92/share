import SwiftUI

/// 两个重叠圆环 + 中间 lime 实心圆点（COMMON §4）。
struct MeshDropMark: View {
    var size: CGFloat = 24
    var strokeColor: Color = MD.dpaper
    var dotColor: Color = MD.lime

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let cy = sz.height / 2
            let r = w * 6.5 / 24
            let leftC  = CGPoint(x: w * 9 / 24,  y: cy)
            let rightC = CGPoint(x: w * 15 / 24, y: cy)
            let strokeW = max(1, w * 2 / 24)

            var leftRing = Path(); leftRing.addEllipse(in: CGRect(x: leftC.x - r,  y: cy - r, width: r*2, height: r*2))
            var rightRing = Path(); rightRing.addEllipse(in: CGRect(x: rightC.x - r, y: cy - r, width: r*2, height: r*2))
            ctx.stroke(leftRing,  with: .color(strokeColor), lineWidth: strokeW)
            ctx.stroke(rightRing, with: .color(strokeColor), lineWidth: strokeW)

            let dotR = w * 1.8 / 24
            let dot = CGRect(x: w/2 - dotR, y: cy - dotR, width: dotR*2, height: dotR*2)
            ctx.fill(Path(ellipseIn: dot), with: .color(dotColor))
        }
        .frame(width: size, height: size)
    }
}

/// Wordmark `meshdrop` + 紧贴的 lime 实心圆点。
struct MeshDropWordmark: View {
    var fontSize: CGFloat = 22
    var color: Color = MD.dpaper

    var body: some View {
        HStack(spacing: fontSize * 0.18) {
            Text("meshdrop")
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .tracking(-fontSize * 0.02)
                .foregroundStyle(color)
            Circle()
                .fill(MD.lime)
                .frame(width: fontSize * 0.28, height: fontSize * 0.28)
                .offset(y: fontSize * 0.28)
        }
        .fixedSize()
    }
}

/// Logo + Wordmark 横排锁定组合。
struct MeshDropLockup: View {
    var size: CGFloat = 28
    var body: some View {
        HStack(spacing: size * 0.45) {
            MeshDropMark(size: size)
            MeshDropWordmark(fontSize: size * 0.78)
        }
    }
}
