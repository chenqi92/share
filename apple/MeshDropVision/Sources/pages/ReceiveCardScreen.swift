import SwiftUI
import MeshDropKit

/// 接收弹卡：左侧文档预览（玻璃 -3°）+ 中央 glass（来源 / 备注 / 双 CTA）。
/// 真接 `engine.pendingFileOffers.first`，双 CTA 走 `respondToFileOffer`。
struct ReceiveCardScreen: View {
    @EnvironmentObject private var engine: ShareEngine

    private var offer: PendingFileOffer? { engine.pendingFileOffers.first }

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            ZStack {
                MDPassthroughBackground(hue: 220)

                if let offer {
                    content(for: offer, canvas: canvas)
                } else {
                    waitingPlaceholder
                        .position(x: canvas.width * 0.5, y: canvas.height * 0.5)
                }

                StatusOrnament()
                    .position(x: canvas.width / 2, y: 44)
            }
        }
    }

    @ViewBuilder
    private func content(for offer: PendingFileOffer, canvas: CGSize) -> some View {
        let senderMock = LivePeerMapper.mockDevice(from: offer.peer, index: 0, total: 1)
        let senderPos  = CGPoint(x: canvas.width - 220, y: 150)

        // 右上 sender PeerOrb（来源）
        PeerOrb(device: senderMock, focused: false)
            .position(senderPos)

        // 中央 CTA 卡
        let centerPos = CGPoint(x: canvas.width * 0.62, y: canvas.height * 0.50)
        receiveCenterCard(for: offer, sender: senderMock)
            .position(centerPos)

        // 左侧 doc 预览
        let leftPos = CGPoint(x: canvas.width * 0.27, y: canvas.height * 0.50)
        docPreviewCard(for: offer)
            .rotation3DEffect(.degrees(-3), axis: (0, 1, 0))
            .position(leftPos)

        // dashed 连接线
        Path { p in
            p.move(to: CGPoint(x: senderPos.x - 110, y: senderPos.y + 40))
            p.addQuadCurve(to: CGPoint(x: centerPos.x + 80, y: centerPos.y - 120),
                           control: CGPoint(x: centerPos.x + 220, y: centerPos.y - 220))
        }
        .stroke(MD.sky.opacity(0.55),
                style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 5]))
    }

    private var waitingPlaceholder: some View {
        GlassCard(corner: 28) {
            VStack(spacing: 12) {
                Text("没有待审的文件")
                    .font(MDFont.heroSmall).foregroundStyle(MD.dpaper)
                Text("WAITING · 等朋友捏合发送")
                    .font(MDFont.microHi).tracking(1.6)
                    .foregroundStyle(MD.dpaper.opacity(0.55))
            }
            .padding(36)
            .frame(width: 420, height: 200)
        }
    }

    // MARK: 左：文档预览
    @ViewBuilder
    private func docPreviewCard(for offer: PendingFileOffer) -> some View {
        let ext = (offer.fileName as NSString).pathExtension.uppercased()
        GlassCard(corner: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    docIcon(ext: ext.isEmpty ? "FILE" : ext)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.fileName)
                            .font(MDFont.cardTitle)
                            .foregroundStyle(MD.dpaper)
                            .lineLimit(2)
                        Text("\(offer.formattedSize) · SHA-256 \(String(offer.sha256.prefix(8)))…")
                            .font(MDFont.micro).mdMonoTracking()
                            .foregroundStyle(MD.dpaper.opacity(0.55))
                    }
                    Spacer()
                    Chip(text: "● LAN", tone: .lime, mono: true)
                }

                // 占位预览（协议 v1 不传 thumbnail）
                VStack(alignment: .leading, spacing: 10) {
                    Text(offer.fileName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(MD.ink)
                    Text("发送方：\(offer.peer.name)")
                        .font(MDFont.bodyEmph)
                        .foregroundStyle(MD.ink.opacity(0.85))
                    Text("接收后会保存到 ~/Documents/MeshDrop/\(offer.peer.name)/")
                        .font(MDFont.body)
                        .foregroundStyle(MD.ink.opacity(0.72))
                    Spacer().frame(height: 4)
                    Text("校验 · CHECKSUM")
                        .font(MDFont.bodyEmph)
                        .foregroundStyle(MD.ink.opacity(0.85))
                    Text(formattedFingerprint(offer.sha256))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MD.ink.opacity(0.72))
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MD.paper)
                )

                HStack(spacing: 10) {
                    Chip(text: ext.isEmpty ? "FILE" : ext, tone: .outline, mono: true)
                    Chip(text: offer.formattedSize, tone: .outline, mono: true)
                    Spacer()
                    Text("已校验 · 待你接收")
                        .font(MDFont.micro)
                        .foregroundStyle(MD.dpaper.opacity(0.55))
                }
            }
            .padding(24)
            .frame(width: 460, height: 600, alignment: .topLeading)
        }
        .shadow(color: .black.opacity(0.5), radius: 36, x: 0, y: 18)
    }

    private func docIcon(ext: String) -> some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 30, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                )
            Path { p in
                p.move(to: CGPoint(x: 22, y: 0))
                p.addLine(to: CGPoint(x: 30, y: 0))
                p.addLine(to: CGPoint(x: 30, y: 8))
                p.closeSubpath()
            }
            .fill(Color.black.opacity(0.08))
            Text(String(ext.prefix(4)))
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(MD.flame)
                .padding(.leading, 4)
                .padding(.bottom, 4)
        }
        .frame(width: 30, height: 38)
    }

    // MARK: 中：CTA
    private func receiveCenterCard(for offer: PendingFileOffer, sender: MockDevice) -> some View {
        GlassCard(corner: 32) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Chip(text: "INCOMING · 接收", tone: .sky, mono: true, leadingDot: Color.white)
                    Spacer()
                    Text(receivedAtLabel(offer.receivedAt))
                        .font(MDFont.micro).tracking(1.4)
                        .foregroundStyle(MD.dpaper.opacity(0.45))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("看一眼，捏合，")
                        .font(MDFont.hero)
                        .foregroundStyle(MD.dpaper)
                    Text("就收到。")
                        .font(MDFont.hero)
                        .foregroundStyle(MD.lime)
                }

                // 发送者卡（嵌入式）
                HStack(spacing: 12) {
                    Avatar(initials: sender.initials,
                           color: sender.color,
                           size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(sender.who).font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
                        Text("\(sender.name) · \(sender.os) · fp \(String(offer.peer.fingerprint.prefix(8)))…")
                            .font(MDFont.micro).mdMonoTracking()
                            .foregroundStyle(MD.dpaper.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MD.lime.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(MD.lime.opacity(0.40), lineWidth: 0.8)
                        )
                )

                // 文件信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill").font(.system(size: 10, weight: .semibold))
                        Text("文件 · FILE").font(MDFont.chipMono).tracking(1.6)
                    }
                    .foregroundStyle(MD.dpaper.opacity(0.55))

                    Text(offer.fileName)
                        .font(MDFont.body)
                        .foregroundStyle(MD.dpaper.opacity(0.92))
                        .lineLimit(2)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                )

                Spacer().frame(height: 2)

                // 双 CTA
                HStack(spacing: 12) {
                    Button {
                        engine.respondToFileOffer(offer.id, accept: false)
                    } label: {
                        ctaLabel(label: "不接收", subtitle: "DECLINE", tone: .ghost)
                    }
                    .buttonStyle(.plain)

                    Button {
                        engine.respondToFileOffer(offer.id, accept: true)
                    } label: {
                        ctaLabel(label: "捏合接收", subtitle: "PINCH · ACCEPT", tone: .accent)
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.lift)
                }
                Text("或:看着这张卡片说\u{201C}接收\u{201D}")
                    .font(MDFont.micro).mdMonoTracking()
                    .foregroundStyle(MD.dpaper.opacity(0.45))
            }
            .padding(24)
            .frame(width: 460, height: 600, alignment: .topLeading)
        }
        .shadow(color: .black.opacity(0.55), radius: 42, x: 0, y: 24)
    }

    enum CTATone { case ghost, accent }

    private func ctaLabel(label: String, subtitle: String, tone: CTATone) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(subtitle)
                .font(MDFont.micro).tracking(1.6)
                .opacity(0.65)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .foregroundStyle(tone == .accent ? MD.ink : MD.dpaper)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tone == .accent ? MD.lime : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18).strokeBorder(
                        tone == .accent ? MD.limeDeep.opacity(0.4) : Color.white.opacity(0.2),
                        lineWidth: 0.8)
                )
        )
    }

    private func receivedAtLabel(_ date: Date) -> String {
        let delta = max(0, Int(Date().timeIntervalSince(date)))
        if delta < 5 { return "JUST NOW" }
        if delta < 60 { return "\(delta)S AGO" }
        return "\(delta / 60)M AGO"
    }

    private func formattedFingerprint(_ hex: String) -> String {
        let upper = hex.uppercased()
        var chunks: [String] = []
        var idx = upper.startIndex
        while idx < upper.endIndex {
            let end = upper.index(idx, offsetBy: 8, limitedBy: upper.endIndex) ?? upper.endIndex
            chunks.append(String(upper[idx..<end]))
            idx = end
        }
        return chunks.prefix(4).joined(separator: " · ")
    }
}
