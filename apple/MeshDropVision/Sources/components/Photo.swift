import SwiftUI

/// 占位 / 缩略图：渐变背景 + 假地平线 + 假太阳 + 假山形（COMMON §7.10）。
struct Photo: View {
    var hue: Double = 28
    var corner: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: [
                    Color(hue: hue/360, saturation: 0.34, brightness: 0.88),
                    Color(hue: (hue+22)/360, saturation: 0.55, brightness: 0.70),
                    Color(hue: (hue+50)/360, saturation: 0.62, brightness: 0.42),
                ], startPoint: .top, endPoint: .bottom)

                // sun
                Circle()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: w * 0.18, height: w * 0.18)
                    .offset(x: -w*0.18, y: -h*0.10)

                // mountain
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h*0.78))
                    p.addLine(to: CGPoint(x: w*0.28, y: h*0.46))
                    p.addLine(to: CGPoint(x: w*0.48, y: h*0.62))
                    p.addLine(to: CGPoint(x: w*0.72, y: h*0.38))
                    p.addLine(to: CGPoint(x: w*0.92, y: h*0.58))
                    p.addLine(to: CGPoint(x: w, y: h*0.66))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(Color(hue: (hue+60)/360, saturation: 0.75, brightness: 0.18))

                // horizon line
                Rectangle()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: 0.6)
                    .offset(y: h*0.30)
            }
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        }
    }
}
