import SwiftUI

/// Radar — MeshDrop 核心组件。
/// - 中心 60×60 实心黑圆 + YOU + 小 mono IP
/// - 3 环同心圆
/// - sweep（旋转扫描臂 4.5s）+ pulse（设备点 halo 2.6s）
/// - 设备点 lime halo (52×52) + avatar dot + label
public struct Radar: View {
    public enum Mode { case sweep, pulse }

    let devices: [MockDevice]
    var mode: Mode = .sweep
    var selectedDevice: MockDevice? = nil
    var diameter: CGFloat = 310

    @Environment(\.colorScheme) private var scheme
    @State private var sweepAngle: Double = 0
    @State private var pulseStep: Double = 0

    public init(devices: [MockDevice], mode: Mode = .sweep,
                selectedDevice: MockDevice? = nil, diameter: CGFloat = 310) {
        self.devices = devices
        self.mode = mode
        self.selectedDevice = selectedDevice
        self.diameter = diameter
    }

    public var body: some View {
        ZStack {
            // 背景 + 环
            radarBackground

            // 同心环 + 罗盘字母
            radarRings

            // sweep arm
            if mode == .sweep {
                sweepArm
            }

            // 设备点
            ForEach(devices) { d in
                deviceDot(d)
            }

            // 中心 YOU
            centerNode

            // 选中设备的虚线连接
            if let sel = selectedDevice {
                selectionLine(to: sel)
            }
        }
        .frame(width: diameter, height: diameter)
        .onAppear {
            withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
                sweepAngle = 360
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                pulseStep = 1
            }
        }
    }

    private var ringColor: Color {
        scheme == .dark ? Color.white.opacity(0.12) : MeshDropColor.ink12
    }

    private var bgColor: Color {
        scheme == .dark ? MeshDropColor.dink2.opacity(0.6) : MeshDropColor.card.opacity(0.5)
    }

    private var radarBackground: some View {
        Circle()
            .fill(bgColor)
            .overlay(
                Circle().strokeBorder(ringColor, lineWidth: 1)
            )
            .overlay(
                // 内部 gradient 微光
                RadialGradient(colors: [
                    MeshDropColor.lime.opacity(scheme == .dark ? 0.08 : 0.12),
                    .clear
                ], center: .center, startRadius: 0, endRadius: diameter * 0.5)
            )
    }

    @ViewBuilder
    private var radarRings: some View {
        ZStack {
            ForEach([1.0, 0.66, 0.33], id: \.self) { factor in
                Circle().stroke(ringColor, style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
                    .frame(width: diameter * factor, height: diameter * factor)
            }
            // 十字线
            Path { p in
                let r = diameter / 2
                p.move(to: CGPoint(x: 0, y: r)); p.addLine(to: CGPoint(x: diameter, y: r))
                p.move(to: CGPoint(x: r, y: 0)); p.addLine(to: CGPoint(x: r, y: diameter))
            }
            .stroke(ringColor, style: StrokeStyle(lineWidth: 0.5, dash: [2, 4]))

            // N / E / S / W
            ForEach(["N", "E", "S", "W"], id: \.self) { dir in
                Text(dir)
                    .font(MeshDropFont.mono(9.5, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.35) : MeshDropColor.ink45)
                    .offset(compassOffset(dir))
            }
        }
    }

    private func compassOffset(_ dir: String) -> CGSize {
        let inset: CGFloat = 8
        let r = diameter / 2 - inset
        switch dir {
        case "N": return CGSize(width: 0, height: -r)
        case "E": return CGSize(width: r, height: 0)
        case "S": return CGSize(width: 0, height: r)
        case "W": return CGSize(width: -r, height: 0)
        default:  return .zero
        }
    }

    @ViewBuilder
    private var sweepArm: some View {
        ZStack {
            // 扇形渐变臂
            AngularGradient(
                gradient: Gradient(stops: [
                    .init(color: MeshDropColor.lime.opacity(0), location: 0.0),
                    .init(color: MeshDropColor.lime.opacity(0.32), location: 0.10),
                    .init(color: MeshDropColor.lime.opacity(0.0), location: 0.20),
                    .init(color: .clear, location: 1.0)
                ]),
                center: .center,
                startAngle: .degrees(0),
                endAngle: .degrees(360)
            )
            .mask(Circle().frame(width: diameter, height: diameter))
            .frame(width: diameter, height: diameter)
            .rotationEffect(.degrees(sweepAngle))
        }
    }

    private func deviceDot(_ d: MockDevice) -> some View {
        let r = diameter / 2 - 30
        let angleRad = (d.angle - 90) * .pi / 180        // 顶部=N
        let x = cos(angleRad) * d.dist * r
        let y = sin(angleRad) * d.dist * r
        let isSel = selectedDevice?.id == d.id

        return ZStack {
            // halo
            Circle()
                .fill((isSel ? MeshDropColor.flame : MeshDropColor.lime).opacity(0.18))
                .frame(width: 52, height: 52)
                .scaleEffect(0.85 + 0.25 * pulseStep)
                .opacity(0.7 - 0.5 * pulseStep)

            // avatar
            Avatar(initials: d.initials, color: d.color, size: 30)

            // label
            HStack(spacing: 4) {
                Text(d.who).font(MeshDropFont.body(11, weight: .semibold))
                Text("\(d.rtt)ms").font(MeshDropFont.mono(9.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.6) : MeshDropColor.ink60)
                    .monospacedDigit()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(scheme == .dark ? MeshDropColor.dink2.opacity(0.92) : MeshDropColor.card.opacity(0.92))
            )
            .overlay(
                Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )
            .offset(x: 0, y: 28)
        }
        .offset(x: x, y: y)
    }

    private var centerNode: some View {
        ZStack {
            Circle().fill(scheme == .dark ? MeshDropColor.dink : MeshDropColor.ink)
                .frame(width: 60, height: 60)
            VStack(spacing: 0) {
                Text("YOU")
                    .font(MeshDropFont.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(MeshDropColor.lime)
                Text(Mock.me.ip)
                    .font(MeshDropFont.mono(8))
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper.opacity(0.7) : MeshDropColor.paper.opacity(0.8))
                    .padding(.top, 1)
            }
        }
    }

    private func selectionLine(to d: MockDevice) -> some View {
        let r = diameter / 2 - 30
        let angleRad = (d.angle - 90) * .pi / 180
        let x = cos(angleRad) * d.dist * r
        let y = sin(angleRad) * d.dist * r

        return Path { p in
            p.move(to: CGPoint(x: diameter/2, y: diameter/2))
            p.addLine(to: CGPoint(x: diameter/2 + x, y: diameter/2 + y))
        }
        .stroke(MeshDropColor.flame, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        .frame(width: diameter, height: diameter)
    }
}
