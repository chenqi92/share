import SwiftUI

enum RadarVariant { case sweep, pulse, grid, orbit }

struct Radar: View {
    var devices: [MockDevice] = []
    var variant: RadarVariant = .sweep
    var selectedDeviceID: String? = nil
    var staticTime: Double? = nil
    var onSelect: (String) -> Void = { _ in }
    var onFiles: (String, [URL]) -> Void = { _, _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || staticTime != nil)) { context in
            GeometryReader { geometry in
                let side = max(0, min(geometry.size.width, geometry.size.height))
                let center = CGPoint(x: side / 2, y: side / 2)
                let radius = max(0, side / 2 - 22)
                let time = staticTime ?? context.date.timeIntervalSinceReferenceDate
                ZStack {
                    Circle().fill(MeshDropColor.cardBg2.opacity(0.55))
                        .frame(width: radius * 2, height: radius * 2)
                    ForEach([0.34, 0.67, 1.0], id: \.self) { fraction in
                        Circle().stroke(MeshDropColor.divider, lineWidth: 1)
                            .frame(width: radius * 2 * fraction, height: radius * 2 * fraction)
                    }
                    if variant == .sweep, !reduceMotion {
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                        }
                        .stroke(MeshDropColor.limeDeep.opacity(0.35), lineWidth: 1)
                        .rotationEffect(.degrees(time.truncatingRemainder(dividingBy: 8) / 8 * 360))
                    }
                    ForEach(devices) { device in
                        let angle = device.angle * .pi / 180 - .pi / 2
                        let distance = radius * min(0.75, max(0.58, device.dist))
                        let point = CGPoint(x: center.x + cos(angle) * distance,
                                            y: center.y + sin(angle) * distance)
                        if device.id == selectedDeviceID {
                            Path { path in
                                path.move(to: center)
                                path.addLine(to: point)
                            }
                            .stroke(MeshDropColor.limeDeep.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        }
                        Button { onSelect(device.id) } label: {
                            VStack(spacing: 5) {
                                Avatar(initials: device.initials, color: device.color, size: 32,
                                       ring: true, ringColor: device.id == selectedDeviceID ? MeshDropColor.limeDeep : MeshDropColor.divider)
                                Text(device.who)
                                    .font(MeshDropFont.body(size: 11, weight: .medium))
                                    .foregroundStyle(MeshDropColor.textPrimary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(MeshDropColor.cardBg, in: Capsule())
                            }
                            .frame(width: 124)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(device.name)
                        .accessibilityLabel(device.who)
                        .dropDestination(for: URL.self) { urls, _ in
                            let files = urls.filter(\.isFileURL)
                            guard !files.isEmpty else { return false }
                            onFiles(device.id, files)
                            return true
                        }
                        .position(x: point.x, y: point.y + 13)
                    }
                    VStack(spacing: 2) {
                        Image(systemName: "laptopcomputer").font(.system(size: 20, weight: .medium))
                        Text("common.me").font(MeshDropFont.body(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(MeshDropColor.outgoingText)
                    .frame(width: 56, height: 56)
                    .background(MeshDropColor.outgoingBubble, in: Circle())
                    .allowsHitTesting(false)
                }
                .frame(width: side, height: side)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }
}
