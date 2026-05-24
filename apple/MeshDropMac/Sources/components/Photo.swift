import SwiftUI

/// 渐变背景 + 假地平线 + 假太阳 + 假山形。按 hue 参数调色。
struct Photo: View {
    var hue: Double = 28
    var aspect: CGFloat = 1.4

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hue: hue / 360, saturation: 0.45, brightness: 0.95),
                        Color(hue: hue / 360, saturation: 0.55, brightness: 0.72),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                // 太阳
                Circle()
                    .fill(Color(hue: ((hue - 20).truncatingRemainder(dividingBy: 360)) / 360,
                                saturation: 0.30, brightness: 1.0))
                    .frame(width: w * 0.22, height: w * 0.22)
                    .offset(x: w * 0.20, y: -h * 0.10)
                // 山
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.78))
                    p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.55))
                    p.addLine(to: CGPoint(x: w * 0.45, y: h * 0.70))
                    p.addLine(to: CGPoint(x: w * 0.65, y: h * 0.48))
                    p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w,        y: h * 0.55))
                    p.addLine(to: CGPoint(x: w,        y: h))
                    p.addLine(to: CGPoint(x: 0,        y: h))
                    p.closeSubpath()
                }
                .fill(Color(hue: hue / 360, saturation: 0.60, brightness: 0.45))
                // 地平线
                Rectangle()
                    .fill(Color(hue: hue / 360, saturation: 0.55, brightness: 0.30))
                    .frame(height: h * 0.18)
                    .offset(y: h * 0.41)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
