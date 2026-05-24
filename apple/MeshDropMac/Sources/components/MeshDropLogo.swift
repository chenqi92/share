import SwiftUI

/// 两个重叠圆环（stroke）+ 中间一个 lime 实心圆点。viewBox 24×24。
/// 暗色背景下 stroke 改 `dpaper`。
struct MeshDropMark: View {
    var size: CGFloat = 28
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let stroke = scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        let strokeW = max(1.5, size * (2.0 / 24.0))
        Canvas { ctx, sz in
            let scale = sz.width / 24.0
            // left ring
            let leftRect = CGRect(x: (9 - 6.5) * scale, y: (12 - 6.5) * scale,
                                  width: 13 * scale, height: 13 * scale)
            // right ring
            let rightRect = CGRect(x: (15 - 6.5) * scale, y: (12 - 6.5) * scale,
                                   width: 13 * scale, height: 13 * scale)
            ctx.stroke(Path(ellipseIn: leftRect),  with: .color(stroke), lineWidth: strokeW)
            ctx.stroke(Path(ellipseIn: rightRect), with: .color(stroke), lineWidth: strokeW)
            // lime dot
            let dot = CGRect(x: (12 - 1.8) * scale, y: (12 - 1.8) * scale,
                             width: 3.6 * scale, height: 3.6 * scale)
            ctx.fill(Path(ellipseIn: dot), with: .color(MeshDropColor.lime))
        }
        .frame(width: size, height: size)
    }
}

/// `meshdrop` 小写 + 紧贴的 lime 实心圆点。Space Grotesk 600, letterSpacing -2.5%。
struct MeshDropWordmark: View {
    var size: CGFloat = 22
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let textColor = scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        HStack(spacing: size * 0.10) {
            Text("meshdrop")
                .font(MeshDropFont.display(size: size, weight: .semibold))
                .tracking(-size * 0.025)
                .foregroundStyle(textColor)
            Circle()
                .fill(MeshDropColor.lime)
                .frame(width: size * 0.32, height: size * 0.32)
                .offset(y: size * 0.30)
        }
    }
}

/// logo + wordmark 横排锁定组合。
struct MeshDropLockup: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: size * 0.34) {
            MeshDropMark(size: size)
            MeshDropWordmark(size: size * 0.80)
        }
    }
}
