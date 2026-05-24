import SwiftUI

/// 巨型雷达：中心黑圆 + 3 环 + sweep 旋转扫描臂 + 设备点 pulse halo。
struct MeshRadar: View {
    var devices: [MeshDevice]
    var diameter: CGFloat = 720
    @State private var sweepAngle: Double = 0
    @State private var pulsePhase: Double = 0

    var body: some View {
        ZStack {
            backdrop
            rings
            sweepArm
            compassMarks
            ForEach(Array(devices.enumerated()), id: \.element.id) { idx, d in
                dot(d, index: idx)
            }
            centerYou
        }
        .frame(width: diameter, height: diameter)
        .onAppear { animate() }
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
                    .stroke(MeshDropColor.dline, style: StrokeStyle(lineWidth: 1.4, dash: [3, 6]))
                    .frame(width: diameter * f, height: diameter * f)
            }
            // 十字线
            Path { p in
                p.move(to: CGPoint(x: 0, y: radius))
                p.addLine(to: CGPoint(x: diameter, y: radius))
                p.move(to: CGPoint(x: radius, y: 0))
                p.addLine(to: CGPoint(x: radius, y: diameter))
            }
            .stroke(MeshDropColor.dlineSoft, style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
        }
    }

    private var sweepArm: some View {
        Canvas { ctx, sz in
            let center = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let r = min(sz.width, sz.height) / 2
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: .degrees(sweepAngle))
            let arc = Path { p in
                p.move(to: .zero)
                p.addArc(center: .zero, radius: r,
                         startAngle: .degrees(-12), endAngle: .degrees(0),
                         clockwise: false)
                p.closeSubpath()
            }
            ctx.fill(
                arc,
                with: .conicGradient(
                    Gradient(colors: [
                        MeshDropColor.lime.opacity(0),
                        MeshDropColor.lime.opacity(0.0),
                        MeshDropColor.lime.opacity(0.45),
                    ]),
                    center: .zero, angle: .degrees(-6)
                )
            )
            // sweep 主臂线
            var arm = Path()
            arm.move(to: .zero)
            arm.addLine(to: CGPoint(x: r, y: 0))
            ctx.stroke(arm, with: .color(MeshDropColor.lime.opacity(0.9)), lineWidth: 2)
        }
        .frame(width: diameter, height: diameter)
        .blendMode(.plusLighter)
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

    private func dot(_ d: MeshDevice, index: Int) -> some View {
        let r = radius * d.dist
        let angle = Angle(degrees: d.angle - 90)  // 0 度朝上
        let cx = CGFloat(cos(angle.radians)) * r
        let cy = CGFloat(sin(angle.radians)) * r
        let phase = pulsePhase + Double(index) * 0.3
        let pulseScale = 0.85 + 0.30 * (0.5 + 0.5 * sin(phase))
        let pulseOpacity = 0.20 + 0.20 * (0.5 - 0.5 * sin(phase))
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
                        .stroke(MeshDropColor.lime, lineWidth: 2)
                )
            VStack(spacing: 2) {
                Text("TV").font(MeshDropFont.monoM()).foregroundStyle(MeshDropColor.lime)
                Text("192.168.1.42")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaperMute)
            }
        }
    }

    private func animate() {
        withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
            sweepAngle = 360
        }
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            pulsePhase = .pi * 2
        }
    }
}
