import SwiftUI

/// gaze 瞄准圈：4 段弧 + 中央十字 + lime 微脉冲 + "看向 LILY · 准备捏合发送" 标签。
struct GazeReticle: View {
    var radius: CGFloat = 80
    // 默认仅作占位；真实使用处（SpatialNearbyPage）总会传入本地化 label。
    var label: String = L10n.nearbyGazeLabel("LILY")
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                // 外圈柔光
                Circle()
                    .stroke(MD.lime.opacity(0.20), lineWidth: 6)
                    .frame(width: radius*2 + 24, height: radius*2 + 24)
                    .blur(radius: 3)
                    .scaleEffect(pulse ? 1.04 : 0.98)

                // 4 段断弧（像瞄准镜分段）
                ForEach(0..<4, id: \.self) { i in
                    let start = Double(i) * 90 + 8
                    let end   = start + 74
                    Arc(startDeg: start, endDeg: end)
                        .stroke(MD.lime, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                        .frame(width: radius*2, height: radius*2)
                }

                // 中央十字
                Path { p in
                    let r = radius * 0.18
                    p.move(to: CGPoint(x: -r, y: 0)); p.addLine(to: CGPoint(x: -r*0.35, y: 0))
                    p.move(to: CGPoint(x: r,  y: 0)); p.addLine(to: CGPoint(x: r*0.35,  y: 0))
                    p.move(to: CGPoint(x: 0, y: -r)); p.addLine(to: CGPoint(x: 0, y: -r*0.35))
                    p.move(to: CGPoint(x: 0, y: r));  p.addLine(to: CGPoint(x: 0, y: r*0.35))
                }
                .offsetBy(dx: radius, dy: radius)
                .stroke(MD.lime, style: StrokeStyle(lineWidth: 1.0, lineCap: .round))
                .frame(width: radius*2, height: radius*2)

                // 中央实心点
                Circle()
                    .fill(MD.lime)
                    .frame(width: 6, height: 6)
                    .shadow(color: MD.lime.opacity(0.6), radius: 8)
            }

            // gaze 标签
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MD.lime)
                Text(label)
                    .font(MDFont.chipMono)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(MD.lime)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(MD.lime.opacity(0.10))
                    .overlay(Capsule().stroke(MD.lime.opacity(0.55), lineWidth: 0.8))
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

/// 简单的圆弧。
private struct Arc: Shape {
    var startDeg: Double
    var endDeg: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.addArc(
            center: center,
            radius: r,
            startAngle: .degrees(startDeg),
            endAngle: .degrees(endDeg),
            clockwise: false
        )
        return p
    }
}

private extension Path {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> Path {
        let transform = CGAffineTransform(translationX: dx, y: dy)
        return self.applying(transform)
    }
}
