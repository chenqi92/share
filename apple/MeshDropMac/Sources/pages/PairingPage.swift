import SwiftUI

struct PairingPage: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        PageScroll {
            VStack(spacing: 22) {
                HStack {
                    Text("配对新设备")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("· Pair a device")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                }

                HStack(alignment: .top, spacing: 22) {
                    // 左：QR 大码
                    VStack(spacing: 14) {
                        Text("扫描 QR 或对比 6 字符代码")
                            .meshTag()
                            .foregroundStyle(MeshDropColor.textMuted)
                        QRPlaceholder()
                            .frame(width: 260, height: 260)
                        Text("FX-3KQ7")
                            .font(MeshDropFont.display(size: 38, weight: .bold))
                            .tracking(4)
                            .foregroundStyle(MeshDropColor.ink)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(MeshDropColor.lime)
                            )
                        Text("两端的代码必须**完全一致**才能配对")
                            .font(MeshDropFont.body(size: 11))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(MeshDropColor.cardBg)
                            .shadow(color: MeshDropColor.ink06, radius: 4, x: 0, y: 2)
                    )

                    // 右：三步说明
                    VStack(alignment: .leading, spacing: 16) {
                        Text("三步完成")
                            .meshTag()
                            .foregroundStyle(MeshDropColor.textMuted)
                        step(1, "在对端 MeshDrop → 设置 → 配对新设备 → 扫描 QR / 输入代码")
                        step(2, "对比两端的 X25519 指纹（4 字符 × 8 组）目视一致")
                        step(3, "双方点 \"允许并记住\"，从此自动信任")

                        AsciiDivider(text: state.enginePairing == nil ? "待审 · PENDING · 0" : "待审 · PENDING · 1")

                        if let p = state.enginePairing {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Avatar(initials: String(p.peer.prefix(2)),
                                           color: Color(hex: 0xFFB4A1), size: 32, ring: true)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(p.deviceName)
                                            .font(MeshDropFont.body(size: 13, weight: .semibold))
                                            .foregroundStyle(MeshDropColor.textPrimary)
                                        Text("\(p.peer) · \(p.receivedAt)")
                                            .font(MeshDropFont.mono(size: 10))
                                            .foregroundStyle(MeshDropColor.textMuted)
                                    }
                                }
                                Text("FP \(p.fingerprint)")
                                    .font(MeshDropFont.mono(size: 11))
                                    .foregroundStyle(MeshDropColor.textSecondary)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(MeshDropColor.cardBg2)
                                    )

                                HStack {
                                    Spacer()
                                    Button {
                                        state.rejectCurrentPairing()
                                    } label: {
                                        Text("拒绝")
                                            .font(MeshDropFont.body(size: 12, weight: .semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(MeshDropColor.divider, lineWidth: 1)
                                            )
                                            .foregroundStyle(MeshDropColor.textSecondary)
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        state.acceptCurrentPairing(trust: true)
                                    } label: {
                                        Text("允许并记住")
                                            .font(MeshDropFont.body(size: 12, weight: .semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(MeshDropColor.lime)
                                            )
                                            .foregroundStyle(MeshDropColor.ink)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(MeshDropColor.limeFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(MeshDropColor.lime, lineWidth: 1)
                                    )
                            )
                        } else {
                            Text("当前没有待审请求")
                                .font(MeshDropFont.body(size: 12))
                                .foregroundStyle(MeshDropColor.textMuted)
                                .padding(14)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(MeshDropColor.cardBg2)
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(MeshDropColor.cardBg)
                            .shadow(color: MeshDropColor.ink06, radius: 4, x: 0, y: 2)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    @ViewBuilder
    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(MeshDropColor.ink).frame(width: 22, height: 22)
                Text("\(n)")
                    .font(MeshDropFont.display(size: 11, weight: .bold))
                    .foregroundStyle(MeshDropColor.paper)
            }
            Text(text)
                .font(MeshDropFont.body(size: 12.5))
                .foregroundStyle(MeshDropColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// QR 占位 — mock 块图 7×7 + finder pattern
struct QRPlaceholder: View {
    var body: some View {
        Canvas { ctx, sz in
            let n = 25
            let cell = sz.width / CGFloat(n)
            ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(.white))
            // 伪随机方块（hash-based 让每次渲染稳定）
            for x in 0..<n {
                for y in 0..<n {
                    let h = (x * 73856093) ^ (y * 19349663)
                    if (h & 0xF) > 7 {
                        ctx.fill(Path(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell,
                                             width: cell - 0.5, height: cell - 0.5)),
                                 with: .color(MeshDropColor.ink))
                    }
                }
            }
            // 3 个 finder pattern
            for (cx, cy) in [(0, 0), (n - 7, 0), (0, n - 7)] {
                ctx.fill(Path(CGRect(x: CGFloat(cx) * cell, y: CGFloat(cy) * cell,
                                     width: 7 * cell, height: 7 * cell)),
                         with: .color(.white))
                ctx.fill(Path(CGRect(x: CGFloat(cx) * cell, y: CGFloat(cy) * cell,
                                     width: 7 * cell, height: 7 * cell)),
                         with: .color(MeshDropColor.ink))
                ctx.fill(Path(CGRect(x: CGFloat(cx + 1) * cell, y: CGFloat(cy + 1) * cell,
                                     width: 5 * cell, height: 5 * cell)),
                         with: .color(.white))
                ctx.fill(Path(CGRect(x: CGFloat(cx + 2) * cell, y: CGFloat(cy + 2) * cell,
                                     width: 3 * cell, height: 3 * cell)),
                         with: .color(MeshDropColor.ink))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(MeshDropColor.divider, lineWidth: 1)
        )
    }
}
