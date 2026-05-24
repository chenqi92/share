import SwiftUI

/// 每个 OS 一个小线条 svg：mac=方框+底线 / win=4 格田字 /
/// ipad=圆角矩形+小圆 / ios&android=圆角窄矩形+底线 / linux=三角企鹅简化。
public struct KindGlyph: View {
    let kind: MockDeviceKind
    var size: CGFloat = 12

    @Environment(\.colorScheme) private var scheme

    public init(_ kind: MockDeviceKind, size: CGFloat = 12) {
        self.kind = kind; self.size = size
    }

    public var body: some View {
        let stroke: Color = scheme == .dark ? Color.white.opacity(0.7) : MeshDropColor.ink80
        let lw: CGFloat = max(1, size / 12)

        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            switch kind {
            case .mac:
                // 方框 + 底线
                let body = Path(roundedRect: CGRect(x: w*0.10, y: h*0.20, width: w*0.80, height: h*0.55), cornerRadius: 1)
                ctx.stroke(body, with: .color(stroke), lineWidth: lw)
                let baseline = Path { p in
                    p.move(to: CGPoint(x: w*0.05, y: h*0.85))
                    p.addLine(to: CGPoint(x: w*0.95, y: h*0.85))
                }
                ctx.stroke(baseline, with: .color(stroke), lineWidth: lw)
            case .win:
                // 田字
                let r = CGRect(x: w*0.15, y: h*0.15, width: w*0.7, height: h*0.7)
                let outer = Path(roundedRect: r, cornerRadius: 1)
                ctx.stroke(outer, with: .color(stroke), lineWidth: lw)
                let cross = Path { p in
                    p.move(to: CGPoint(x: w*0.5, y: h*0.15)); p.addLine(to: CGPoint(x: w*0.5, y: h*0.85))
                    p.move(to: CGPoint(x: w*0.15, y: h*0.5)); p.addLine(to: CGPoint(x: w*0.85, y: h*0.5))
                }
                ctx.stroke(cross, with: .color(stroke), lineWidth: lw)
            case .ipad:
                // 圆角矩形 + 中央小圆
                let body = Path(roundedRect: CGRect(x: w*0.20, y: h*0.10, width: w*0.60, height: h*0.80), cornerRadius: 2)
                ctx.stroke(body, with: .color(stroke), lineWidth: lw)
                let dot = Path(ellipseIn: CGRect(x: w*0.45, y: h*0.75, width: w*0.10, height: w*0.10))
                ctx.fill(dot, with: .color(stroke))
            case .ios, .android:
                // 圆角窄矩形 + 顶部 home indicator 底线
                let body = Path(roundedRect: CGRect(x: w*0.28, y: h*0.05, width: w*0.44, height: h*0.90), cornerRadius: 3)
                ctx.stroke(body, with: .color(stroke), lineWidth: lw)
                let baseline = Path { p in
                    p.move(to: CGPoint(x: w*0.42, y: h*0.83))
                    p.addLine(to: CGPoint(x: w*0.58, y: h*0.83))
                }
                ctx.stroke(baseline, with: .color(stroke), lineWidth: lw)
            case .linux:
                // 简化菱形
                let body = Path { p in
                    p.move(to: CGPoint(x: w*0.5, y: h*0.10))
                    p.addLine(to: CGPoint(x: w*0.85, y: h*0.85))
                    p.addLine(to: CGPoint(x: w*0.15, y: h*0.85))
                    p.closeSubpath()
                }
                ctx.stroke(body, with: .color(stroke), lineWidth: lw)
            }
        }
        .frame(width: size, height: size)
    }
}
