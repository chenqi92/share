import Darwin
import SwiftUI

enum RadarVariant { case sweep, pulse, grid, orbit }

/// 核心组件。中心 60×60 实心黑圆 + 同心 3 环 + sweep / pulse 变体 + 设备点。
struct Radar: View {
    var devices: [MockDevice] = []
    var variant: RadarVariant = .sweep
    var selectedDeviceID: String? = nil
    /// 由 caller 注入 TimelineView date —— 这样静态 ImageRenderer 也能给出"特定时刻"快照。
    var staticTime: Double? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        TimelineView(.animation) { ctx in
            radarContent(time: staticTime ?? ctx.date.timeIntervalSinceReferenceDate)
        }
    }

    @ViewBuilder
    private func radarContent(time t: Double) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxR = side / 2 - 16

            ZStack {
                    // 背景圆
                    Circle()
                        .fill(MeshDropColor.cardBg2)
                        .frame(width: side, height: side)

                    // 同心 3 环
                    ForEach([0.33, 0.66, 1.0], id: \.self) { r in
                        Circle()
                            .stroke(MeshDropColor.divider, lineWidth: 1)
                            .frame(width: maxR * 2 * r, height: maxR * 2 * r)
                    }

                    // 十字线 + 罗盘字母
                    Path { p in
                        p.move(to: CGPoint(x: center.x - maxR, y: center.y))
                        p.addLine(to: CGPoint(x: center.x + maxR, y: center.y))
                        p.move(to: CGPoint(x: center.x, y: center.y - maxR))
                        p.addLine(to: CGPoint(x: center.x, y: center.y + maxR))
                    }
                    .stroke(MeshDropColor.divider, style: StrokeStyle(lineWidth: 0.5, dash: [3, 4]))

                    Group {
                        Text("N").position(x: center.x, y: center.y - maxR - 8)
                        Text("E").position(x: center.x + maxR + 8, y: center.y)
                        Text("S").position(x: center.x, y: center.y + maxR + 8)
                        Text("W").position(x: center.x - maxR - 8, y: center.y)
                    }
                    .font(MeshDropFont.mono(size: 9, weight: .bold))
                    .foregroundStyle(MeshDropColor.textMuted)

                    // sweep arm
                    if variant == .sweep {
                        SweepArm(time: t, radius: maxR)
                            .position(center)
                    }

                    // grid 点阵
                    if variant == .grid {
                        Canvas { ctx, sz in
                            let step: CGFloat = 12
                            for x in stride(from: step, to: sz.width, by: step) {
                                for y in stride(from: step, to: sz.height, by: step) {
                                    let dx = x - sz.width / 2
                                    let dy = y - sz.height / 2
                                    if sqrt(dx * dx + dy * dy) < maxR {
                                        let rect = CGRect(x: x, y: y, width: 1.5, height: 1.5)
                                        ctx.fill(Path(ellipseIn: rect),
                                                 with: .color(MeshDropColor.divider))
                                    }
                                }
                            }
                        }
                    }

                    // 中心 YOU
                    VStack(spacing: 1) {
                        Text("YOU")
                            .font(MeshDropFont.mono(size: 10, weight: .bold))
                            .foregroundStyle(scheme == .dark ? MeshDropColor.ink : MeshDropColor.paper)
                        Text(DeviceDot.localAddressOrPlaceholder())
                            .font(MeshDropFont.mono(size: 7))
                            .foregroundStyle(scheme == .dark ? MeshDropColor.ink60 : MeshDropColor.paper.opacity(0.7))
                    }
                    .padding(6)
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.ink))

                    // 设备点
                    ForEach(Array(devices.enumerated()), id: \.element.id) { idx, dev in
                        let isSel = dev.id == selectedDeviceID
                        let theta = dev.angle * .pi / 180.0 - .pi / 2  // 12 点方向是 0°
                        let r = maxR * dev.dist
                        let x = center.x + cos(theta) * r
                        let y = center.y + sin(theta) * r

                        // selected 时从中心一条 flame 虚线
                        if isSel {
                            Path { p in
                                p.move(to: center)
                                p.addLine(to: CGPoint(x: x, y: y))
                            }
                            .stroke(MeshDropColor.flame,
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }

                        DevicePulse(time: t, delay: Double(idx) * 0.3,
                                    color: isSel ? MeshDropColor.flame : MeshDropColor.lime)
                            .position(x: x, y: y)

                        DeviceDot(device: dev, selected: isSel)
                            .position(x: x, y: y)

                        // label 旁边
                        Text("\(dev.who) · \(dev.rtt)ms")
                            .font(MeshDropFont.mono(size: 9))
                            .foregroundStyle(MeshDropColor.textSecondary)
                            .position(x: x + 30, y: y)
                    }
                }
                .frame(width: side, height: side)
                .position(center)
            }
        }
    }


private struct SweepArm: View {
    let time: Double
    let radius: CGFloat

    var body: some View {
        let angle = (time.truncatingRemainder(dividingBy: 4.5)) / 4.5 * 360
        // 从 frame 圆心向右边缘画一条线；frame 中心即雷达圆心，
        // rotationEffect 默认绕 frame 中心旋转，扫描臂才会从圆心扫出。
        Path { p in
            p.move(to: CGPoint(x: radius, y: radius))
            p.addLine(to: CGPoint(x: radius * 2, y: radius))
        }
        .stroke(LinearGradient(
            colors: [MeshDropColor.lime, MeshDropColor.lime.opacity(0.05)],
            startPoint: .center,
            endPoint: .trailing
        ), lineWidth: 2)
        .frame(width: radius * 2, height: radius * 2)
        .rotationEffect(.degrees(angle - 90))
    }
}

private struct DevicePulse: View {
    let time: Double
    let delay: Double
    let color: Color

    var body: some View {
        let phase = (time + delay).truncatingRemainder(dividingBy: 2.4) / 2.4
        let scale = 0.3 + phase * 0.9
        let opacity = max(0, 0.9 - phase * 0.9)
        Circle()
            .fill(color)
            .frame(width: 52, height: 52)
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

private struct DeviceDot: View {
    let device: MockDevice
    var selected: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .fill(selected ? MeshDropColor.flame : MeshDropColor.lime)
                .frame(width: 36, height: 36)
            Avatar(initials: device.initials, color: device.color, size: 30)
        }
    }

    /// 取本机第一块非 loopback IPv4 地址；拿不到时显示占位。
    /// 仅用于雷达中心 "YOU" 标签的副文案，不参与协议。
    static func localAddressOrPlaceholder() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return "—" }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let flags = Int32(cur.pointee.ifa_flags)
            let addr = cur.pointee.ifa_addr.pointee
            if (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING),
               (flags & IFF_LOOPBACK) == 0,
               addr.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(cur.pointee.ifa_addr,
                               socklen_t(cur.pointee.ifa_addr.pointee.sa_len),
                               &host, socklen_t(host.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    address = String(cString: host)
                    break
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return address ?? "—"
    }
}
