import SwiftUI

/// 两个重叠圆环 + 中心 lime 实心圆点。viewBox 24×24 等比缩放。
struct MeshDropMark: View {
    var size: CGFloat = 36
    var stroke: Color = MeshDropColor.dpaper

    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height) / 24
            let strokeW: CGFloat = 2 * s
            // 左圈：cx=9, r=6.5
            let leftRect = CGRect(x: (9 - 6.5) * s, y: (12 - 6.5) * s, width: 13 * s, height: 13 * s)
            ctx.stroke(Path(ellipseIn: leftRect), with: .color(stroke), lineWidth: strokeW)
            // 右圈：cx=15
            let rightRect = CGRect(x: (15 - 6.5) * s, y: (12 - 6.5) * s, width: 13 * s, height: 13 * s)
            ctx.stroke(Path(ellipseIn: rightRect), with: .color(stroke), lineWidth: strokeW)
            // 中心实心 lime 圆点：cx=12, r=1.8
            let dotRect = CGRect(x: (12 - 1.8) * s, y: (12 - 1.8) * s, width: 3.6 * s, height: 3.6 * s)
            ctx.fill(Path(ellipseIn: dotRect), with: .color(MeshDropColor.lime))
        }
        .frame(width: size, height: size)
    }
}

/// `meshdrop` + 紧贴的 lime 实心圆点；末尾点不能省。
struct MeshDropWordmark: View {
    var size: CGFloat = 36
    var color: Color = MeshDropColor.dpaper

    var body: some View {
        HStack(spacing: 0) {
            Text("meshdrop")
                .font(.system(size: size, weight: .bold, design: .default))
                .tracking(-size * 0.025)
                .foregroundStyle(color)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Circle()
                .fill(MeshDropColor.lime)
                .frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.04, y: size * 0.32)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct MeshDropLockup: View {
    var size: CGFloat = 44
    var color: Color = MeshDropColor.dpaper

    var body: some View {
        HStack(spacing: size * 0.28) {
            MeshDropMark(size: size, stroke: color)
            MeshDropWordmark(size: size * 0.78, color: color)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}
