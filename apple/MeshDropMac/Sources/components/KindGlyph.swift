import SwiftUI

/// 每 OS 一个小线条 svg。size 10-12，用于设备 row 副标题前置。
struct KindGlyph: View {
    let kind: DeviceKind
    var size: CGFloat = 11
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height
            ctx.stroke(path(in: CGRect(x: 0, y: 0, width: w, height: h)),
                       with: .color(c), lineWidth: 1.2)
        }
        .frame(width: size, height: size)
    }

    private func path(in r: CGRect) -> Path {
        var p = Path()
        switch kind {
        case .mac:
            // 方框 + 底线
            p.addRect(CGRect(x: r.minX + r.width * 0.10, y: r.minY + r.height * 0.20,
                             width: r.width * 0.80, height: r.height * 0.55))
            p.move(to:    CGPoint(x: r.minX + r.width * 0.05, y: r.minY + r.height * 0.92))
            p.addLine(to: CGPoint(x: r.maxX - r.width * 0.05, y: r.minY + r.height * 0.92))
        case .win:
            // 4 格田字
            let m = r.width * 0.12
            let inner = CGRect(x: r.minX + m, y: r.minY + m,
                               width: r.width - m * 2, height: r.height - m * 2)
            p.addRect(inner)
            p.move(to:    CGPoint(x: inner.midX, y: inner.minY))
            p.addLine(to: CGPoint(x: inner.midX, y: inner.maxY))
            p.move(to:    CGPoint(x: inner.minX, y: inner.midY))
            p.addLine(to: CGPoint(x: inner.maxX, y: inner.midY))
        case .ipad:
            // 圆角矩形 + 小圆
            let rect = CGRect(x: r.minX + r.width * 0.18, y: r.minY + r.height * 0.05,
                              width: r.width * 0.64, height: r.height * 0.90)
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: 1.5, height: 1.5))
            p.addEllipse(in: CGRect(x: rect.midX - 0.6, y: rect.maxY - 2.2,
                                    width: 1.2, height: 1.2))
        case .ios, .android:
            // 窄圆角矩形 + 底线
            let rect = CGRect(x: r.minX + r.width * 0.28, y: r.minY + r.height * 0.08,
                              width: r.width * 0.44, height: r.height * 0.78)
            p.addRoundedRect(in: rect, cornerSize: CGSize(width: 1.2, height: 1.2))
            p.move(to:    CGPoint(x: rect.midX - rect.width * 0.20, y: rect.maxY + 1))
            p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.20, y: rect.maxY + 1))
        }
        return p
    }
}
