import SwiftUI
import MeshDropKit

/// 进行中传输：飞行轨迹根据真实 outgoing/incoming history 实时绘制；
/// 中央"飞行中"任务面板显示每个 transfer 的真实 byte 进度。
struct TransfersPage: View {
    @EnvironmentObject private var engine: ShareEngine

    private var livePeers: [MockDevice] {
        LivePeerMapper.map(engine.devices)
    }

    private var inFlight: [MockData.InFlightTransfer] {
        LiveTransferMapper.inFlight(from: engine.history,
                                    selfName: engine.displayName)
    }

    private var outBps: UInt64 { 0 } // 协议暂不暴露速率，留 placeholder
    private var inBps:  UInt64 { 0 }

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            let selfPos = CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.5)
            ZStack {
                MDPassthroughBackground(hue: 12)

                // 静态浮岛：真实 peer
                ForEach(livePeers) { dev in
                    PeerOrb(device: dev)
                        .position(peerScreenPos(for: dev, canvas: canvas))
                        .zIndex(zIndex(for: dev))
                }

                // 真实飞行轨迹：根据 transfer.peer + direction 决定起终点
                ForEach(inFlight) { tr in
                    if let trailEndpoints = endpoints(for: tr, selfPos: selfPos, canvas: canvas) {
                        FlyingPayload(
                            from: trailEndpoints.from,
                            to:   trailEndpoints.to,
                            color: tr.direction == .outgoing ? MD.flame : MD.sky,
                            staticPreview: false
                        )
                        .zIndex(15)
                    }
                }

                // 中央"飞行中"任务面板
                inFlightPanel
                    .position(CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.52))
                    .zIndex(40)

                // 顶部 status ornament
                StatusOrnament()
                    .position(x: canvas.width / 2, y: 44)
                    .zIndex(50)
                // 底 tab
                TabOrnamentStatic(current: .transfers)
                    .position(x: canvas.width / 2, y: canvas.height - 50)
                    .zIndex(50)
            }
        }
    }

    private func endpoints(for tr: MockData.InFlightTransfer,
                           selfPos: CGPoint,
                           canvas: CGSize) -> (from: CGPoint, to: CGPoint)? {
        let peerId: String
        switch tr.direction {
        case .outgoing: peerId = tr.toId
        case .incoming: peerId = tr.fromId
        }
        guard let peer = livePeers.first(where: { $0.id == peerId }) else {
            return nil
        }
        let peerPos = peerScreenPos(for: peer, canvas: canvas)
        if tr.direction == .outgoing {
            return (from: selfPos, to: peerPos)
        } else {
            return (from: peerPos, to: selfPos)
        }
    }

    private func zIndex(for dev: MockDevice) -> Double {
        switch dev.depthLayer {
        case .near: return 11
        case .mid:  return 8
        case .far:  return 5
        }
    }

    private var inFlightPanel: some View {
        GlassCard(corner: 32) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("飞行中 · IN FLIGHT")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(MD.dpaper)
                    Spacer()
                    Chip(text: "● \(inFlight.count) ACTIVE",
                         tone: inFlight.isEmpty ? .outline : .flame, mono: true)
                }

                if inFlight.isEmpty {
                    emptyState
                } else {
                    ASCIIDivider(label: "ACTIVE · 进行中")
                    ForEach(inFlight) { tr in
                        transferRow(tr)
                    }
                    Text("看向轨迹任意一段 · 捏合可暂停 / 取消")
                        .font(MDFont.micro).mdMonoTracking()
                        .foregroundStyle(MD.dpaper.opacity(0.45))
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .frame(width: 620, height: 380, alignment: .topLeading)
        }
        .shadow(color: .black.opacity(0.5), radius: 36, x: 0, y: 22)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("没有进行中的传输")
                .font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
            Text("EMPTY · 在附近页面 pinch 一台设备试试")
                .font(MDFont.microHi).tracking(1.6)
                .foregroundStyle(MD.dpaper.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func transferRow(_ tr: MockData.InFlightTransfer) -> some View {
        let isOut = (tr.direction == .outgoing)
        let stateColor: Color = isOut ? MD.flame : MD.sky
        HStack(spacing: 14) {
            fileIcon(ext: tr.ext, accent: stateColor)
                .frame(width: 38, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(tr.name)
                        .font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
                        .lineLimit(1)
                    Spacer()
                    Text("\(isOut ? "→" : "←") \(peerName(for: isOut ? tr.toId : tr.fromId))")
                        .font(MDFont.micro).mdMonoTracking()
                        .foregroundStyle(stateColor)
                }

                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(stateColor)
                            .frame(width: g.size.width * tr.progress)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 12) {
                    Text(tr.size)
                        .font(MDFont.micro).mdMonoTracking()
                        .foregroundStyle(MD.dpaper.opacity(0.6))
                    Text("\(Int(tr.progress * 100))%")
                        .font(MDFont.microHi).mdMonoTracking()
                        .foregroundStyle(stateColor)
                    Spacer()
                    Chip(text: isOut ? "SENDING" : "RECEIVING",
                         tone: isOut ? .flame : .sky, mono: true)
                }
            }
        }
    }

    private func peerName(for id: String) -> String {
        if id == "me" { return "我" }
        if let p = livePeers.first(where: { $0.id == id }) {
            return p.who
        }
        return String(id.prefix(8))
    }

    private func fileIcon(ext: String, accent: Color) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 5).stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                )
            Path { p in
                p.move(to: CGPoint(x: 28, y: 0))
                p.addLine(to: CGPoint(x: 38, y: 0))
                p.addLine(to: CGPoint(x: 38, y: 10))
                p.closeSubpath()
            }
            .fill(Color.black.opacity(0.08))
            Text(String(ext.uppercased().prefix(4)))
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.leading, 5)
                .padding(.bottom, 5)
        }
    }
}
