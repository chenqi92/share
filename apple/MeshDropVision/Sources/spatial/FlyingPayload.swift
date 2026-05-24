import SwiftUI

/// 飞行 payload 轨迹：从起点（手 / self）画到终点（gaze focus peer），沿途撒粒子。
/// visionOS 上跑动画即可看见 trail；静态截图也能看清 dashed trail。
struct FlyingPayload: View {
    let from: CGPoint
    let to: CGPoint
    var color: Color = MD.lime
    /// 0...1，粒子在轨迹上的当前位置
    @State private var t: Double = 0
    /// 静态预览用：true 时不跑动画，让粒子停在 0.78（截图友好）
    var staticPreview: Bool = false

    var body: some View {
        ZStack {
            // 1) 主体 dashed 轨迹（轻微弧形）
            curvePath()
                .stroke(color.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round,
                                           dash: [3, 4]))

            // 2) 飞行中"信封" —— 玻璃圆点 + lime 边
            payloadCapsule()
                .position(curvePoint(at: t))

            // 3) 残影粒子（沿轨迹散布）
            ForEach(0..<6, id: \.self) { i in
                let phase = max(0, t - Double(i + 1) * 0.06)
                Circle()
                    .fill(color.opacity(0.55 - Double(i) * 0.08))
                    .frame(width: max(2, 8 - Double(i) * 1.0),
                           height: max(2, 8 - Double(i) * 1.0))
                    .position(curvePoint(at: phase))
                    .blur(radius: Double(i) * 0.4)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            if staticPreview {
                t = 0.78
            } else {
                t = 0
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    t = 1.0
                }
            }
        }
    }

    private func payloadCapsule() -> some View {
        ZStack {
            Circle().fill(color.opacity(0.18))
                .frame(width: 30, height: 30)
                .blur(radius: 4)
            Circle().fill(color)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))
        }
    }

    private func curvePath() -> Path {
        Path { p in
            p.move(to: from)
            p.addQuadCurve(to: to, control: control)
        }
    }

    /// 控制点：从 from→to 中点向"上"（屏幕坐标 y 减小）偏移 22%。
    private var control: CGPoint {
        let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
        let dist = hypot(to.x - from.x, to.y - from.y)
        return CGPoint(x: mid.x, y: mid.y - dist * 0.22)
    }

    /// 沿 quad 曲线参数 t 的位置。
    private func curvePoint(at t: Double) -> CGPoint {
        let one_t = 1 - t
        let x = one_t * one_t * from.x + 2 * one_t * t * control.x + t * t * to.x
        let y = one_t * one_t * from.y + 2 * one_t * t * control.y + t * t * to.y
        return CGPoint(x: x, y: y)
    }
}
