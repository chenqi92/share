import SwiftUI

/// 占位图：渐变背景 + 假地平线 + 假太阳 + 假山形。
struct PhotoPlaceholder: View {
    var hue: Double = 0.5
    var aspect: CGFloat = 3.0 / 2.0
    var corner: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: hue, saturation: 0.55, brightness: 0.65),
                        Color(hue: (hue + 0.10).truncatingRemainder(dividingBy: 1), saturation: 0.42, brightness: 0.38),
                        Color(hue: (hue + 0.18).truncatingRemainder(dividingBy: 1), saturation: 0.50, brightness: 0.22),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 假太阳
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.85), Color.white.opacity(0)],
                            center: .center, startRadius: 0, endRadius: geo.size.width * 0.18
                        )
                    )
                    .frame(width: geo.size.width * 0.32, height: geo.size.width * 0.32)
                    .position(x: geo.size.width * 0.72, y: geo.size.height * 0.38)

                // 假地平线
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1.2)
                    .offset(y: geo.size.height * 0.10)

                // 假山形
                Path { p in
                    let w = geo.size.width, h = geo.size.height
                    let baseY = h * 0.72
                    p.move(to: CGPoint(x: 0, y: baseY))
                    p.addLine(to: CGPoint(x: w * 0.20, y: baseY - h * 0.18))
                    p.addLine(to: CGPoint(x: w * 0.35, y: baseY - h * 0.05))
                    p.addLine(to: CGPoint(x: w * 0.55, y: baseY - h * 0.24))
                    p.addLine(to: CGPoint(x: w * 0.70, y: baseY - h * 0.10))
                    p.addLine(to: CGPoint(x: w * 0.85, y: baseY - h * 0.21))
                    p.addLine(to: CGPoint(x: w, y: baseY - h * 0.06))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(Color.black.opacity(0.55))

                // 一点点 mono 噪点装饰：grain dot
                Rectangle()
                    .fill(Color.white.opacity(0.04))
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
