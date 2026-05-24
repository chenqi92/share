import SwiftUI

/// 巨型雷达：中心黑圆 + 3 环 + sweep 旋转扫描臂 + 设备点 pulse halo。
/// 动画用 TimelineView(.animation) 驱动，避免 tvOS 上 Canvas 内 withAnimation 不刷新。
struct MeshRadar: View {
    var devices: [MeshDevice]
    var diameter: CGFloat = 720

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let sweepAngle = (t.truncatingRemainder(dividingBy: 4.5)) / 4.5 * 360.0
            let pulsePhase = (t.truncatingRemainder(dividingBy: 2.6)) / 2.6 * .pi * 2

            ZStack {
                backdrop
                rings
                sweepArm(angle: sweepAngle)
                compassMarks
                ForEach(Array(devices.enumerated()), id: \.element.id) { idx, d in
                    dot(d, index: idx, phase: pulsePhase)
                }
                centerYou
            }
            .frame(width: diameter, height: diameter)
        }
    }

    private var radius: CGFloat { diameter / 2 }

    private var backdrop: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        MeshDropColor.dink2.opacity(0.6),
                        MeshDropColor.dink.opacity(0.0),
                    ],
                    center: .center, startRadius: 0, endRadius: radius
                )
            )
            .frame(width: diameter, height: diameter)
    }

    private var rings: some View {
        ZStack {
            ForEach([0.33, 0.66, 1.0], id: \.self) { f in
                Circle()
                    .stroke(Color.white.opacity(0.22), style: StrokeStyle(lineWidth: 1.5, dash: [5, 9]))
                    .frame(width: diameter * f, height: diameter * f)
            }
            // 十字线
            Path { p in
                p.move(to: CGPoint(x: 0, y: radius))
                p.addLine(to: CGPoint(x: diameter, y: radius))
                p.move(to: CGPoint(x: radius, y: 0))
                p.addLine(to: CGPoint(x: radius, y: diameter))
            }
            .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 8]))
        }
    }

    private func sweepArm(angle: Double) -> some View {
        ZStack {
            // 扫描扇形（用渐变 mask 叠加 lime）
            Circle()
                .trim(from: 0, to: 0.08)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            MeshDropColor.lime.opacity(0),
                            MeshDropColor.lime.opacity(0.50),
                        ]),
                        center: .center,
                        startAngle: .degrees(-30),
                        endAngle: .degrees(0)
                    ),
                    style: StrokeStyle(lineWidth: radius, lineCap: .butt)
                )
                .frame(width: radius, height: radius)
                .rotationEffect(.degrees(angle - 90))
                .blendMode(.plusLighter)

            // 主扫描臂：从圆心到边缘一条 lime 实线
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [MeshDropColor.lime.opacity(0.0), MeshDropColor.lime],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: radius, height: 2)
                .offset(x: radius / 2)
                .rotationEffect(.degrees(angle - 90))
        }
        .frame(width: diameter, height: diameter)
    }

    private var compassMarks: some View {
        ZStack {
            Text("N").offset(y: -radius + 24)
            Text("E").offset(x: radius - 24)
            Text("S").offset(y: radius - 24)
            Text("W").offset(x: -radius + 24)
        }
        .foregroundStyle(MeshDropColor.dpaperMute)
        .font(MeshDropFont.monoTag())
        .tracking(2)
    }

    private func dot(_ d: MeshDevice, index: Int, phase: Double) -> some View {
        let r = radius * d.dist
        let angle = Angle(degrees: d.angle - 90)
        let cx = CGFloat(cos(angle.radians)) * r
        let cy = CGFloat(sin(angle.radians)) * r
        let localPhase = phase + Double(index) * 0.6
        let pulseScale = 0.85 + 0.30 * (0.5 + 0.5 * sin(localPhase))
        let pulseOpacity = 0.22 + 0.18 * (0.5 - 0.5 * sin(localPhase))
        return ZStack {
            Circle()
                .fill(MeshDropColor.lime.opacity(pulseOpacity))
                .frame(width: 76, height: 76)
                .scaleEffect(pulseScale)
            Avatar(initials: d.initials, color: d.color, size: 48)
            VStack(spacing: 2) {
                Text(d.who).font(.system(size: 16, weight: .bold)).foregroundStyle(MeshDropColor.dpaper)
                Text("\(d.os) · \(d.rtt)ms")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaperMute)
            }
            .offset(y: 56)
        }
        .offset(x: cx, y: cy)
    }

    private var centerYou: some View {
        ZStack {
            Circle()
                .fill(MeshDropColor.dink)
                .frame(width: 110, height: 110)
                .overlay(
                    Circle()
                        .strokeBorder(MeshDropColor.lime, lineWidth: 2)
                )
            VStack(spacing: 2) {
                Text("TV").font(MeshDropFont.monoM()).foregroundStyle(MeshDropColor.lime)
                Text("192.168.1.42")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaperMute)
            }
        }
    }
}
