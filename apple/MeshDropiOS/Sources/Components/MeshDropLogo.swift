import SwiftUI

/// 双圆环 + lime 实心圆点 logo（COMMON §4）。viewBox 24×24。
public struct MeshDropMark: View {
    public var size: CGFloat = 24
    @Environment(\.colorScheme) private var scheme

    public init(size: CGFloat = 24) { self.size = size }

    public var body: some View {
        let stroke: Color = scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        let lw = size / 12      // 2 / 24

        ZStack {
            Circle()
                .stroke(stroke, lineWidth: lw)
                .frame(width: size * 13/24, height: size * 13/24)
                .offset(x: -size * 1.5/24)
            Circle()
                .stroke(stroke, lineWidth: lw)
                .frame(width: size * 13/24, height: size * 13/24)
                .offset(x: size * 1.5/24)
            Circle()
                .fill(MeshDropColor.lime)
                .frame(width: size * 3.6/24, height: size * 3.6/24)
        }
        .frame(width: size, height: size)
    }
}

/// 字标 `meshdrop.` 小写 + lime 实心圆点。
public struct MeshDropWordmark: View {
    public var size: CGFloat = 18
    @Environment(\.colorScheme) private var scheme

    public init(size: CGFloat = 18) { self.size = size }

    public var body: some View {
        let ink: Color = scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink

        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("meshdrop")
                .font(MeshDropFont.display(size, weight: .semibold))
                .tracking(-size * 0.025)        // letterSpacing -2.5%
                .foregroundStyle(ink)
            Text(".")
                .font(MeshDropFont.display(size, weight: .semibold))
                .foregroundStyle(MeshDropColor.lime)
        }
    }
}

/// logo + wordmark 锁定组合（横排）。
public struct MeshDropLockup: View {
    public var size: CGFloat
    public init(size: CGFloat = 22) { self.size = size }

    public var body: some View {
        HStack(spacing: size * 0.36) {
            MeshDropMark(size: size + 2)
            MeshDropWordmark(size: size)
        }
    }
}
