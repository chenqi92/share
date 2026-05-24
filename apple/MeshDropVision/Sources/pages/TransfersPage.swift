import SwiftUI

/// 进行中传输：3 个文件分别从 self / Kun 飞向不同 peer。
/// 中央同时显示一个简洁的"任务列表"玻璃面板（与传统列表风不同 — 是 spatial-friendly 的紧凑式）。
struct TransfersPage: View {

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            let selfPos   = CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.5)
            let mxPos     = peerScreenPos(for: MockData.device("mengxi"), canvas: canvas)
            let jwPos     = peerScreenPos(for: MockData.device("jiawei"), canvas: canvas)
            let kunPos    = peerScreenPos(for: MockData.device("kun"),    canvas: canvas)

            ZStack {
                MDPassthroughBackground(hue: 12)

                // 5 个 peer 静态浮岛
                ForEach(MockData.devices) { dev in
                    PeerOrb(device: dev)
                        .position(peerScreenPos(for: dev, canvas: canvas))
                        .zIndex(zIndex(for: dev))
                }

                // 3 条飞行轨迹（与 MockData.inFlight 对齐）
                FlyingPayload(from: selfPos, to: mxPos,  color: MD.flame, staticPreview: true)
                    .zIndex(15)
                FlyingPayload(from: selfPos, to: jwPos,  color: MD.flame, staticPreview: true)
                    .zIndex(15)
                FlyingPayload(from: kunPos,  to: selfPos, color: MD.sky,  staticPreview: true)
                    .zIndex(15)

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
                    Chip(text: "● 3 ACTIVE", tone: .flame, mono: true)
                    Chip(text: "↑ 11.5 MB/s", tone: .outline, mono: true)
                    Chip(text: "↓ 11.7 MB/s", tone: .outline, mono: true)
                }

                ASCIIDivider(label: "OUTGOING · 上行 · 我 → 朋友")

                ForEach(MockData.inFlight) { tr in
                    transferRow(tr)
                }

                Text("看向轨迹任意一段 · 捏合可暂停 / 取消")
                    .font(MDFont.micro).mdMonoTracking()
                    .foregroundStyle(MD.dpaper.opacity(0.45))
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 22)
            .frame(width: 620, height: 380, alignment: .topLeading)
        }
        .shadow(color: .black.opacity(0.5), radius: 36, x: 0, y: 22)
    }

    @ViewBuilder
    private func transferRow(_ tr: MockData.InFlightTransfer) -> some View {
        let isOut = (tr.direction == .outgoing)
        let stateColor: Color = isOut ? MD.flame : MD.sky
        HStack(spacing: 14) {
            // 文件 icon
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

                // progress bar
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
                    Text(tr.speed)
                        .font(MDFont.micro).mdMonoTracking()
                        .foregroundStyle(MD.dpaper.opacity(0.6))
                    Text("ETA \(tr.eta)")
                        .font(MDFont.micro).mdMonoTracking()
                        .foregroundStyle(MD.dpaper.opacity(0.6))
                    Spacer()
                    Chip(text: isOut ? "SENDING" : "RECEIVING",
                         tone: isOut ? .flame : .sky, mono: true)
                }
            }
        }
    }

    private func peerName(for id: String) -> String {
        if id == "me" { return "我" }
        return MockData.device(id).who
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
            Text(ext.uppercased())
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(accent)
                .padding(.leading, 5)
                .padding(.bottom, 5)
        }
    }
}
