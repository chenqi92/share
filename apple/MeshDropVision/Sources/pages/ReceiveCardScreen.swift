import SwiftUI

/// 接收弹卡：左侧大 glass（文档预览，倾斜 -3°）+ 中央 glass（来源 / 备注 / 双 CTA）。
struct ReceiveCardScreen: View {
    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            ZStack {
                MDPassthroughBackground(hue: 220)

                // 右上角 sender PeerOrb（嘉伟）
                let senderPos = CGPoint(x: canvas.width - 220, y: 150)
                PeerOrb(device: MockData.device("jiawei"), focused: false)
                    .position(senderPos)

                // 中央 glass panel：核心 CTA
                let centerPos = CGPoint(x: canvas.width * 0.62, y: canvas.height * 0.50)
                receiveCenterCard
                    .position(centerPos)

                // 文档预览面板（左，倾斜 -3°）
                let leftPos = CGPoint(x: canvas.width * 0.27, y: canvas.height * 0.50)
                docPreviewCard
                    .rotation3DEffect(.degrees(-3), axis: (0, 1, 0))
                    .position(leftPos)

                // dashed 连接线：从右上 sender 到中央卡片
                Path { p in
                    p.move(to: CGPoint(x: senderPos.x - 110, y: senderPos.y + 40))
                    p.addQuadCurve(to: CGPoint(x: centerPos.x + 80, y: centerPos.y - 120),
                                   control: CGPoint(x: centerPos.x + 220, y: centerPos.y - 220))
                }
                .stroke(MD.sky.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 5]))

                // 顶部 status ornament
                StatusOrnament()
                    .position(x: canvas.width / 2, y: 44)
            }
        }
    }

    // MARK: 左：文档预览
    private var docPreviewCard: some View {
        GlassCard(corner: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    docIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(MockData.pendingOffer.fileName)
                            .font(MDFont.cardTitle)
                            .foregroundStyle(MD.dpaper)
                        Text("\(MockData.pendingOffer.fileSize) · \(MockData.pendingOffer.pageCount)")
                            .font(MDFont.micro).mdMonoTracking()
                            .foregroundStyle(MD.dpaper.opacity(0.55))
                    }
                    Spacer()
                    Chip(text: "● E2E", tone: .lime, mono: true)
                }

                // 假"页面" preview
                VStack(alignment: .leading, spacing: 10) {
                    Text("2026 Q1 设计规划")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(MD.ink)
                    Text("§1  目标")
                        .font(MDFont.bodyEmph)
                        .foregroundStyle(MD.ink.opacity(0.85))
                    Text("围绕 MeshDrop 跨端一致性,在 2026 Q1 把五端 UI 统一到\n新的报纸 + lime 设计语言.")
                        .font(MDFont.body)
                        .foregroundStyle(MD.ink.opacity(0.72))
                    Spacer().frame(height: 4)
                    Text("§2  端任务拆分")
                        .font(MDFont.bodyEmph)
                        .foregroundStyle(MD.ink.opacity(0.85))
                    Text("§2.1 macOS · 玻璃 sidebar + 雷达\n§2.2 iOS · 单手 + 卡片层叠\n§2.3 visionOS · 空间漂浮 + gaze/pinch")
                        .font(MDFont.body)
                        .foregroundStyle(MD.ink.opacity(0.72))
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MD.paper)
                )

                HStack(spacing: 10) {
                    Chip(text: "PDF", tone: .outline, mono: true)
                    Chip(text: "3.4 MB", tone: .outline, mono: true)
                    Chip(text: "12 页", tone: .outline, mono: true)
                    Spacer()
                    Text("已加密 · 待你接收")
                        .font(MDFont.micro)
                        .foregroundStyle(MD.dpaper.opacity(0.55))
                }
            }
            .padding(24)
            .frame(width: 460, height: 600, alignment: .topLeading)
        }
        .shadow(color: .black.opacity(0.5), radius: 36, x: 0, y: 18)
    }

    private var docIcon: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.white)
                .frame(width: 30, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 4).stroke(Color.black.opacity(0.2), lineWidth: 0.5)
                )
            // 折角
            Path { p in
                p.move(to: CGPoint(x: 22, y: 0))
                p.addLine(to: CGPoint(x: 30, y: 0))
                p.addLine(to: CGPoint(x: 30, y: 8))
                p.closeSubpath()
            }
            .fill(Color.black.opacity(0.08))
            // ext label
            Text("PDF")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .foregroundStyle(MD.flame)
                .padding(.leading, 4)
                .padding(.bottom, 4)
        }
        .frame(width: 30, height: 38)
    }

    // MARK: 中：CTA
    private var receiveCenterCard: some View {
        GlassCard(corner: 32) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Chip(text: "INCOMING · 接收", tone: .sky, mono: true, leadingDot: Color.white)
                    Spacer()
                    Text(MockData.pendingOffer.receivedAt.uppercased())
                        .font(MDFont.micro).tracking(1.4)
                        .foregroundStyle(MD.dpaper.opacity(0.45))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("看一眼,捏合,")
                        .font(MDFont.hero)
                        .foregroundStyle(MD.dpaper)
                    Text("就收到.")
                        .font(MDFont.hero)
                        .foregroundStyle(MD.lime)
                }

                // 发送者卡（嵌入式）
                HStack(spacing: 12) {
                    Avatar(initials: "JW",
                           color: MockData.device("jiawei").color,
                           size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("嘉伟").font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
                        Text("Jiawei · iPad · 9 ms · 已配对 ● 已验证指纹")
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

                // note 便签
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "tag.fill").font(.system(size: 10, weight: .semibold))
                        Text("便签 · NOTE").font(MDFont.chipMono).tracking(1.6)
                    }
                    .foregroundStyle(MD.dpaper.opacity(0.55))

                    Text("\u{201C}\(MockData.pendingOffer.note)\u{201D}")
                        .font(MDFont.body)
                        .foregroundStyle(MD.dpaper.opacity(0.92))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
                )

                Spacer().frame(height: 2)

                // 双 CTA
                HStack(spacing: 12) {
                    ctaButton(label: "不接收", subtitle: "DECLINE", tone: .ghost)
                    ctaButton(label: "捏合接收", subtitle: "PINCH · ACCEPT", tone: .accent)
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

    private func ctaButton(label: String, subtitle: String, tone: CTATone) -> some View {
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
}
