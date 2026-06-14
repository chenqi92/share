import SwiftUI
import UniformTypeIdentifiers
import MeshDropKit

/// 主页：飘浮设备 + 中央窗口 + gaze reticle 锁定 + 飞行轨迹。
/// gaze 锁定一台 PeerOrb 后，"捏合" → 弹文件选择 → engine.sendFile。
struct SpatialNearbyPage: View {
    @EnvironmentObject private var engine: ShareEngine
    @State private var focusedPeerId: String?
    @State private var showFileImporter = false
    @State private var sendTargetId: String?

    private var livePeers: [MockDevice] {
        LivePeerMapper.map(engine.devices)
    }

    private var focusedDevice: MockDevice? {
        if let id = focusedPeerId, let p = livePeers.first(where: { $0.id == id }) {
            return p
        }
        return livePeers.first
    }

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            ZStack {
                MDPassthroughBackground(hue: 28)

                // 漂浮的 PeerOrb（按 dist / angle 散布）
                ForEach(livePeers) { dev in
                    let pos = peerScreenPos(for: dev, canvas: canvas)
                    PeerOrb(device: dev,
                            focused: dev.id == focusedDevice?.id,
                            showSendCue: dev.id == focusedDevice?.id)
                        .position(pos)
                        .zIndex(zIndex(for: dev))
                        // gaze + pinch = 单击；先 focus，再 pinch 触发发送
                        .onTapGesture {
                            if focusedPeerId == dev.id {
                                // 已 focus，第二次 pinch → 开文件选择
                                sendTargetId = dev.id
                                showFileImporter = true
                            } else {
                                focusedPeerId = dev.id
                            }
                        }
                        .contextMenu {
                            contextMenuButtons(for: dev)
                        }
                        .accessibilityLabel(L10n.nearbyOrbA11y(dev.who))
                }

                // 飞行 payload：从中央 self 出发飞向 gaze 锁定的 peer
                if let f = focusedDevice {
                    FlyingPayload(
                        from: CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.5 + 120),
                        to:   peerScreenPos(for: f, canvas: canvas),
                        color: MD.lime,
                        staticPreview: false
                    )
                }

                // 中央主窗口（最前一层 zIndex）
                MainWindow()
                    .zIndex(20)

                // 空态 / scanning 提示
                if livePeers.isEmpty {
                    emptyHint(scanning: engine.isStarting)
                        .position(x: canvas.width / 2, y: canvas.height * 0.78)
                        .zIndex(22)
                }

                // gaze reticle 浮在 focused peer 上空
                if let f = focusedDevice {
                    GazeReticle(
                        radius: 70,
                        label: L10n.nearbyGazeLabel(f.who.uppercased())
                    )
                    .position(reticlePosition(for: f, canvas: canvas))
                    .zIndex(25)
                }

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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImporter(result: result)
        }
    }

    // MARK: - empty / scanning hint

    @ViewBuilder
    private func emptyHint(scanning: Bool) -> some View {
        VStack(spacing: 8) {
            Text(scanning ? L10n.nearbyScanning : L10n.nearbyWaiting)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(MD.dpaper)
            Text(scanning ? L10n.nearbyScanningSub : L10n.nearbyEmptySub)
                .font(MDFont.microHi).tracking(1.6)
                .foregroundStyle(MD.lime)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .glassBackgroundEffect(in: Capsule())
    }

    // MARK: - 操作

    @ViewBuilder
    private func contextMenuButtons(for dev: MockDevice) -> some View {
        Button(L10n.nearbySendFileTo(dev.who)) {
            sendTargetId = dev.id
            showFileImporter = true
        }
        if let real = engine.devices.first(where: { $0.id == dev.id }) {
            Button(L10n.nearbyRevokeTrust) {
                engine.revokeTrust(fingerprint: real.fingerprint)
            }
        }
    }

    private func handleFileImporter(result: Result<[URL], Error>) {
        defer { sendTargetId = nil }
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard let target = sendTargetId.flatMap({ id in
            engine.devices.first(where: { $0.id == id })
        }) else { return }
        engine.sendFile(to: target, sourceURL: url)
    }

    // MARK: - 几何

    private func zIndex(for dev: MockDevice) -> Double {
        switch dev.depthLayer {
        case .near: return 12
        case .mid:  return 8
        case .far:  return 4
        }
    }

    private func reticlePosition(for dev: MockDevice, canvas: CGSize) -> CGPoint {
        let p = peerScreenPos(for: dev, canvas: canvas)
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
