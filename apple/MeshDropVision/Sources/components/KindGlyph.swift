import SwiftUI

/// 设备种类小线条标识（COMMON §7.4）。size 10~14。
struct KindGlyph: View {
    let kind: MeshDropKind
    var size: CGFloat = 12

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height
            let s: CGFloat = max(0.9, w / 14)
            let stroke = GraphicsContext.Shading.color(MD.dpaper.opacity(0.78))

            switch kind {
            case .mac:
                // 方框 + 底线
                let body = CGRect(x: w*0.10, y: h*0.15, width: w*0.80, height: h*0.55)
                ctx.stroke(Path(roundedRect: body, cornerRadius: 1.2), with: stroke, lineWidth: s)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: w*0.30, y: h*0.85))
                    p.addLine(to: CGPoint(x: w*0.70, y: h*0.85))
                }, with: stroke, lineWidth: s)

            case .win:
                // 4 格田字
                let r = CGRect(x: w*0.12, y: h*0.12, width: w*0.76, height: h*0.76)
                ctx.stroke(Path(roundedRect: r, cornerRadius: 1.0), with: stroke, lineWidth: s)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: w*0.5, y: r.minY)); p.addLine(to: CGPoint(x: w*0.5, y: r.maxY))
                    p.move(to: CGPoint(x: r.minX, y: h*0.5)); p.addLine(to: CGPoint(x: r.maxX, y: h*0.5))
                }, with: stroke, lineWidth: s*0.85)

            case .ipad:
                // 圆角矩形 + 小圆
                let body = CGRect(x: w*0.16, y: h*0.10, width: w*0.68, height: h*0.80)
                ctx.stroke(Path(roundedRect: body, cornerRadius: 2.4), with: stroke, lineWidth: s)
                let dot = CGRect(x: w*0.45, y: h*0.78, width: w*0.10, height: w*0.10)
                ctx.stroke(Path(ellipseIn: dot), with: stroke, lineWidth: s*0.85)

            case .ios, .android:
                // 圆角窄矩形 + 底线
                let body = CGRect(x: w*0.30, y: h*0.08, width: w*0.40, height: h*0.84)
                ctx.stroke(Path(roundedRect: body, cornerRadius: 2.6), with: stroke, lineWidth: s)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: w*0.40, y: h*0.78))
                    p.addLine(to: CGPoint(x: w*0.60, y: h*0.78))
                }, with: stroke, lineWidth: s*0.85)
            }
        }
        .frame(width: size, height: size)
    }
}
