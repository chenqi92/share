import SwiftUI
import MeshDropKit

/// 配对页：把短码 + 完整指纹 + "捏合确认" CTA 接到真实 `engine.pendingPairings.first`。
/// 没有待审请求时显示等待 placeholder。
struct PairingPage: View {
    @EnvironmentObject private var engine: ShareEngine

    private var request: PairingRequest? { engine.pendingPairings.first }

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            ZStack {
                MDPassthroughBackground(hue: 156)

                if let request {
                    let peerMock = LivePeerMapper.mockDevice(from: request.peer, index: 0, total: 1)
                    PeerOrb(device: peerMock, focused: true)
                        .position(x: canvas.width * 0.22, y: canvas.height * 0.32)

                    Path { p in
                        p.move(to: CGPoint(x: canvas.width * 0.22 + 130, y: canvas.height * 0.32 + 40))
                        p.addQuadCurve(
                            to: CGPoint(x: canvas.width * 0.5 - 200, y: canvas.height * 0.5),
                            control: CGPoint(x: canvas.width * 0.36, y: canvas.height * 0.30))
                    }
                    .stroke(MD.lime.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 5]))

                    pairingCard(for: request)
                        .position(x: canvas.width * 0.58, y: canvas.height * 0.50)
                } else {
                    waitingPlaceholder
                        .position(x: canvas.width * 0.5, y: canvas.height * 0.5)
                }

                StatusOrnament()
                    .position(x: canvas.width / 2, y: 44)
                TabOrnamentStatic(current: .pairing)
                    .position(x: canvas.width / 2, y: canvas.height - 50)
            }
        }
    }

    private var waitingPlaceholder: some View {
        GlassCard(corner: 28) {
            VStack(spacing: 10) {
                Text(L10n.pairingNoPending)
                    .font(MDFont.heroSmall).foregroundStyle(MD.dpaper)
                Text(L10n.pairingNoPendingSub)
                    .font(MDFont.microHi).tracking(1.6)
                    .foregroundStyle(MD.dpaper.opacity(0.55))
            }
            .padding(40)
            .frame(width: 440, height: 220)
        }
    }

    private func pairingCard(for req: PairingRequest) -> some View {
        GlassCard(corner: 32) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Chip(text: L10n.pairingFirstTag,
                         tone: .lime, mono: true, leadingDot: MD.limeDeep)
                    Spacer()
                    Text(L10n.pairingWaitingConfirm)
                        .font(MDFont.microHi).tracking(1.6)
                        .foregroundStyle(MD.dpaper.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.pairingWithPeer(req.peer.name))
                        .font(MDFont.heroSmall)
                        .foregroundStyle(MD.dpaper)
                    Text(L10n.pairingCompareHint)
                        .font(MDFont.body)
                        .foregroundStyle(MD.dpaper.opacity(0.6))
                }

                // 短码 = 真指纹前 6 hex 按 2 字符分 3 组
                HStack(spacing: 12) {
                    ForEach(shortCodeChunks(req.peer.fingerprint), id: \.self) { chunk in
                        Text(chunk)
                            .font(.system(size: 34, weight: .heavy, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(MD.lime)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 22)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(MD.lime.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(MD.lime.opacity(0.55), lineWidth: 0.9)
                                    )
                            )
                    }
                }

                ASCIIDivider(label: L10n.pairingDivider)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(fingerprintRows(req.peer.humanFingerprint), id: \.self) { row in
                        Text(row)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(MD.dpaper.opacity(0.92))
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6)
                )

                HStack(spacing: 12) {
                    Button {
                        engine.respondToPairing(req.id, decision: .reject)
                    } label: {
                        pairingCTA(title: L10n.pairingRejectTitle,
                                   subtitle: L10n.pairingRejectSub, accent: false)
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.respondToPairing(req.id, decision: .trust)
                    } label: {
                        pairingCTA(title: L10n.pairingConfirmTitle,
                                   subtitle: L10n.pairingConfirmSub,
                                   accent: true)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                }

                Text(L10n.pairingRememberHint)
                    .font(MDFont.micro).mdMonoTracking()
                    .foregroundStyle(MD.dpaper.opacity(0.45))
            }
            .padding(28)
            .frame(width: 580, height: 660, alignment: .topLeading)
        }
        .shadow(color: .black.opacity(0.55), radius: 42, x: 0, y: 22)
    }

    private func pairingCTA(title: String, subtitle: String, accent: Bool) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(subtitle).font(MDFont.micro).tracking(1.6).opacity(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(accent ? MD.ink : MD.dpaper)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(accent ? MD.lime : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18).strokeBorder(
                        accent ? MD.limeDeep.opacity(0.4) : Color.white.opacity(0.2),
                        lineWidth: 0.8)
                )
        )
    }

    /// 从 32 hex 指纹取前 6 个字符，分成 3 组 2 字符。
    private func shortCodeChunks(_ fp: String) -> [String] {
        let upper = fp.uppercased()
        let prefix = String(upper.prefix(6))
        var chunks: [String] = []
        var idx = prefix.startIndex
        while idx < prefix.endIndex {
            let end = prefix.index(idx, offsetBy: 2, limitedBy: prefix.endIndex) ?? prefix.endIndex
            chunks.append(String(prefix[idx..<end]))
            idx = end
        }
        return chunks
    }

    /// 人眼指纹（8 组 4 hex 空格分隔）按每行 4 组拆。
    private func fingerprintRows(_ human: String) -> [String] {
        let groups = human.split(separator: " ").map(String.init)
        var rows: [String] = []
        var buf: [String] = []
        for g in groups {
            buf.append(g)
            if buf.count == 4 {
                rows.append(buf.joined(separator: " · "))
                buf.removeAll()
            }
        }
        if !buf.isEmpty { rows.append(buf.joined(separator: " · ")) }
        return rows
    }
}
