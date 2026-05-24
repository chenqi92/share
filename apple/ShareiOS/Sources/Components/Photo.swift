import SwiftUI

/// 占位 / 缩略图：渐变背景 + 假地平线 + 假太阳 + 假山形。
public struct Photo: View {
    let hue: Int
    public init(hue: Int) { self.hue = hue }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: Double((hue) % 360) / 360.0, saturation: 0.32, brightness: 0.95),
                        Color(hue: Double((hue + 30) % 360) / 360.0, saturation: 0.55, brightness: 0.75)
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                // 太阳
                Circle()
                    .fill(Color(hue: Double((hue + 10) % 360) / 360.0, saturation: 0.5, brightness: 1.0))
                    .frame(width: w * 0.30, height: w * 0.30)
                    .position(x: w * 0.72, y: h * 0.30)
                    .blur(radius: 1)
                    .opacity(0.95)

                // 远山
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.62))
                    p.addLine(to: CGPoint(x: w * 0.25, y: h * 0.40))
                    p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.55))
                    p.addLine(to: CGPoint(x: w * 0.78, y: h * 0.32))
                    p.addLine(to: CGPoint(x: w, y: h * 0.52))
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.addLine(to: CGPoint(x: 0, y: h))
                    p.closeSubpath()
                }
                .fill(Color(hue: Double((hue + 200) % 360) / 360.0, saturation: 0.30, brightness: 0.40))

                // 地平线
                Rectangle()
                    .fill(Color(hue: Double((hue + 30) % 360) / 360.0, saturation: 0.45, brightness: 0.25))
                    .frame(height: h * 0.18)
                    .position(x: w * 0.5, y: h * 0.91)
            }
            .clipShape(Rectangle())
        }
    }
}
