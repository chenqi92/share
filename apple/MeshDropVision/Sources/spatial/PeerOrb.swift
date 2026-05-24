import SwiftUI

/// 漂浮在空间里的设备小卡（260×160 圆角 28 玻璃卡）。
/// 远近按 depthLayer 自动缩放 / 模糊 / 衰减透明度。
struct PeerOrb: View {
    let device: MockDevice
    var focused: Bool = false
    /// `true` 时显示 `→ 发送` 行动按钮（focus + selected payload 状态）
    var showSendCue: Bool = false

    @State private var halo = false

    private var layer: DepthLayer { device.depthLayer }

    var body: some View {
        let scale = focused ? layer.scale * 1.05 : layer.scale
        ZStack {
            // halo（在线脉冲）
            Circle()
                .fill(
                    RadialGradient(colors: [
                        MD.lime.opacity(0.32),
                        MD.lime.opacity(0.02),
                        .clear,
                    ], center: .center, startRadius: 0, endRadius: 160)
                )
                .frame(width: 320, height: 320)
                .scaleEffect(halo ? 1.10 : 0.92)
                .opacity(halo ? 0.4 : 0.85)
                .blendMode(.plusLighter)

            GlassCard(corner: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 12) {
                        Avatar(initials: device.initials, color: device.color, size: 42,
                               ring: focused, ringColor: MD.lime)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                KindGlyph(kind: device.kind, size: 11)
                                Text(device.who)
                                    .font(MDFont.cardTitle)
                                    .foregroundStyle(MD.dpaper)
                            }
                            Text(device.name)
                                .font(MDFont.label)
                                .foregroundStyle(MD.dpaper.opacity(0.65))
                                .lineLimit(1)
                        }
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        Chip(text: "ONLINE", tone: .lime, mono: true, leadingDot: MD.limeDeep)
                        Chip(text: "\(device.rtt) ms", tone: .outline, mono: true)
                        Spacer()
                        Text("≈ \(formattedMeters)")
                            .font(MDFont.micro).mdMonoTracking()
                            .foregroundStyle(MD.dpaper.opacity(0.55))
                    }

                    if showSendCue {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.pinch.fill")
                                .foregroundStyle(MD.lime)
                                .font(.system(size: 12, weight: .semibold))
                            Text("捏合 · 发送 3 张照片 → \(device.who)")
                                .font(MDFont.label)
                                .foregroundStyle(MD.dpaper.opacity(0.92))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(MD.lime.opacity(0.16))
                                .overlay(Capsule().stroke(MD.lime.opacity(0.55), lineWidth: 0.8))
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(width: 260, height: showSendCue ? 178 : 158, alignment: .topLeading)
            }
            .overlay(
                // 选中态外圈 lime ring（focus）
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(MD.lime, lineWidth: focused ? 1.6 : 0)
                    .opacity(focused ? 1 : 0)
            )
        }
        .scaleEffect(scale)
        .opacity(layer.opacity)
        .blur(radius: layer.blur)
        .shadow(color: .black.opacity(0.35), radius: focused ? 28 : 18, x: 0, y: focused ? 18 : 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                halo.toggle()
            }
        }
    }

    private var formattedMeters: String {
        String(format: "%.1f m", device.approxMeters)
    }
}
