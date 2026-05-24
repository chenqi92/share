import SwiftUI

/// 配对页：6 字符短码 block + 完整指纹 + "捏合确认" CTA + 对端 PeerOrb 在侧。
struct PairingPage: View {
    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            ZStack {
                MDPassthroughBackground(hue: 156)

                // 对端 PeerOrb（李莉，左上角悬浮）
                PeerOrb(device: MockData.device("lily"), focused: true)
                    .position(x: canvas.width * 0.22, y: canvas.height * 0.32)

                // dashed 连线（peer → 中央卡）
                Path { p in
                    p.move(to: CGPoint(x: canvas.width * 0.22 + 130, y: canvas.height * 0.32 + 40))
                    p.addQuadCurve(
                        to: CGPoint(x: canvas.width * 0.5 - 200, y: canvas.height * 0.5),
                        control: CGPoint(x: canvas.width * 0.36, y: canvas.height * 0.30))
                }
                .stroke(MD.lime.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [4, 5]))

                // 中央配对卡片
                pairingCard
                    .position(x: canvas.width * 0.58, y: canvas.height * 0.50)

                // 顶部 status ornament
                StatusOrnament()
                    .position(x: canvas.width / 2, y: 44)
                // 底 tab
                TabOrnamentStatic(current: .pairing)
                    .position(x: canvas.width / 2, y: canvas.height - 50)
            }
        }
    }

    private var pairingCard: some View {
        GlassCard(corner: 32) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Chip(text: "FIRST PAIRING · 首次配对",
                         tone: .lime, mono: true, leadingDot: MD.limeDeep)
                    Spacer()
                    Text("WAITING · 等待对端确认")
                        .font(MDFont.microHi).tracking(1.6)
                        .foregroundStyle(MD.dpaper.opacity(0.55))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("和李莉的 MacBook")
                        .font(MDFont.heroSmall)
                        .foregroundStyle(MD.dpaper)
                    Text("对一下这串字符,确认是同一台.")
                        .font(MDFont.body)
                        .foregroundStyle(MD.dpaper.opacity(0.6))
                }

                // 6 字符短码（大字号 block）
                HStack(spacing: 12) {
                    ForEach(splitShortCode(MockData.pairing.shortCode), id: \.self) { chunk in
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

                ASCIIDivider(label: "Fingerprint · 完整指纹 · ED25519")

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(splitFingerprint(MockData.pairing.fingerprintFull), id: \.self) { row in
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

                // 双 CTA
                HStack(spacing: 12) {
                    pairingCTA(title: "不,这台不对",
                               subtitle: "REJECT", accent: false)
                    pairingCTA(title: "✥ 捏合确认 · 是同一台",
                               subtitle: "PINCH · CONFIRM",
                               accent: true)
                }

                Text("一旦确认,这台设备会被记住;以后互发不再弹此卡片.")
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

    /// 把 "QX-7M-93" 拆成 ["QX", "7M", "93"]
    private func splitShortCode(_ code: String) -> [String] {
        code.split(separator: "-").map(String.init)
    }

    /// 把完整指纹按 4 组 / 行显示。
    private func splitFingerprint(_ fp: String) -> [String] {
        let groups = fp.components(separatedBy: " · ")
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
