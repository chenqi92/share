import SwiftUI

struct Avatar: View {
    let initials: String
    let color: Color
    let size: CGFloat
    var ring: Bool = false
    var ringColor: Color = MD.lime

    var body: some View {
        ZStack {
            if ring {
                Circle()
                    .stroke(ringColor, lineWidth: max(1.5, size * 0.06))
                    .frame(width: size + 6, height: size + 6)
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text(initials)
                .font(MDFont.display(size * 0.42, weight: .bold))
                .foregroundColor(MD.dink)
                .tracking(-0.2)
        }
        .frame(width: size + (ring ? 8 : 0), height: size + (ring ? 8 : 0))
    }
}

/// 设备类型 glyph（10-12 pt 小线条）
struct KindGlyph: View {
    let kind: String
    let size: CGFloat
    init(kind: String, size: CGFloat = 10) { self.kind = kind; self.size = size }

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height
            let stroke = max(1.0, w * 0.10)
            let strokeStyle = StrokeStyle(lineWidth: stroke, lineCap: .round)
            let c = MD.muted

            switch kind {
            case "mac":
                var p = Path()
                p.addRoundedRect(in: CGRect(x: w*0.10, y: h*0.20, width: w*0.80, height: h*0.55), cornerSize: CGSize(width: 1, height: 1))
                ctx.stroke(p, with: .color(c), style: strokeStyle)
                var line = Path()
                line.move(to: CGPoint(x: w*0.30, y: h*0.85))
                line.addLine(to: CGPoint(x: w*0.70, y: h*0.85))
                ctx.stroke(line, with: .color(c), style: strokeStyle)
            case "win":
                let g = 2.0
                let cellW = (w - g*3 - w*0.10*2) / 2
                let cellH = (h - g*3 - h*0.10*2) / 2
                for i in 0..<2 {
                    for j in 0..<2 {
                        var r = Path()
                        r.addRect(CGRect(x: w*0.10 + g + Double(i)*(cellW+g), y: h*0.10 + g + Double(j)*(cellH+g), width: cellW, height: cellH))
                        ctx.stroke(r, with: .color(c), style: strokeStyle)
                    }
                }
            case "ipad":
                var p = Path()
                p.addRoundedRect(in: CGRect(x: w*0.18, y: h*0.10, width: w*0.64, height: h*0.80), cornerSize: CGSize(width: 1.5, height: 1.5))
                ctx.stroke(p, with: .color(c), style: strokeStyle)
                var dot = Path(ellipseIn: CGRect(x: w*0.45, y: h*0.78, width: w*0.10, height: w*0.10))
                ctx.fill(dot, with: .color(c))
            case "ios", "android":
                var p = Path()
                p.addRoundedRect(in: CGRect(x: w*0.28, y: h*0.08, width: w*0.44, height: h*0.78), cornerSize: CGSize(width: 1.5, height: 1.5))
                ctx.stroke(p, with: .color(c), style: strokeStyle)
                var line = Path()
                line.move(to: CGPoint(x: w*0.42, y: h*0.78))
                line.addLine(to: CGPoint(x: w*0.58, y: h*0.78))
                ctx.stroke(line, with: .color(c), style: strokeStyle)
            default:
                var p = Path()
                p.addRoundedRect(in: CGRect(x: w*0.2, y: h*0.2, width: w*0.6, height: h*0.6), cornerSize: CGSize(width: 1, height: 1))
                ctx.stroke(p, with: .color(c), style: strokeStyle)
            }
        }
        .frame(width: size, height: size)
    }
}
