import SwiftUI

/// 主页：飘浮设备 + 中央窗口 + gaze reticle 锁定 Lily + 飞行轨迹。
struct SpatialNearbyPage: View {
    @State private var focusedPeerId: String = "lily"
    @State private var showTrail: Bool = true

    private var focusedDevice: MockDevice {
        MockData.device(focusedPeerId)
    }

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            ZStack {
                // 远景：passthrough 替身
                MDPassthroughBackground(hue: 28)

                // 漂浮的 5 个 PeerOrb（按 dist / angle 散布）
                ForEach(MockData.devices) { dev in
                    let pos = peerScreenPos(for: dev, canvas: canvas)
                    PeerOrb(device: dev,
                            focused: dev.id == focusedPeerId,
                            showSendCue: dev.id == focusedPeerId)
                        .position(pos)
                        .zIndex(zIndex(for: dev))
                }

                // 飞行 payload：从中央 self 出发飞向 gaze 锁定的 peer
                if showTrail {
                    FlyingPayload(
                        from: CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.5 + 120),
                        to:   peerScreenPos(for: focusedDevice, canvas: canvas),
                        color: MD.lime,
                        staticPreview: false
                    )
                }

                // 中央主窗口（最前一层 zIndex）
                MainWindow()
                    .zIndex(20)

                // gaze reticle 浮在 Lily 上空
                GazeReticle(
                    radius: 70,
                    label: "看向 \(focusedDevice.who.uppercased()) · 准备捏合发送"
                )
                .position(reticlePosition(canvas: canvas))
                .zIndex(25)

                // 顶部 status ornament
                StatusOrnament()
                    .position(x: canvas.width / 2, y: 44)
                    .zIndex(30)

                // 底部 tab ornament
                TabOrnamentStatic(current: .nearby)
                    .position(x: canvas.width / 2, y: canvas.height - 50)
                    .zIndex(30)

                // 左下 close handle
                CloseHandleOrnament()
                    .position(x: 60, y: canvas.height - 50)
                    .zIndex(30)
            }
        }
    }

    private func zIndex(for dev: MockDevice) -> Double {
        switch dev.depthLayer {
        case .near: return 12
        case .mid:  return 8
        case .far:  return 4
        }
    }

    /// reticle 放在 focused peer 略上方。
    private func reticlePosition(canvas: CGSize) -> CGPoint {
        let p = peerScreenPos(for: focusedDevice, canvas: canvas)
        return CGPoint(x: p.x, y: p.y - 110)
    }
}

/// SpatialNearbyPage 等页面里直接用的静态 TabOrnament（不需要 binding）。
struct TabOrnamentStatic: View {
    let current: AppTab
    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                HStack(spacing: 8) {
                    Image(systemName: tab.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                    Text(tab.label)
                        .font(MDFont.label)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minWidth: 110)
                .background(
                    Capsule()
                        .fill(current == tab ? MD.lime.opacity(0.18) : .clear)
                        .overlay(
                            Capsule().stroke(
                                current == tab ? MD.lime.opacity(0.55) : .clear,
                                lineWidth: 1)
                        )
                )
                .foregroundStyle(current == tab ? MD.lime : MD.dpaper.opacity(0.75))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBackgroundEffect(in: Capsule())
    }
}
