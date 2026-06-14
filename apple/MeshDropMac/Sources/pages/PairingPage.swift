import SwiftUI

struct PairingPage: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        PageScroll {
            VStack(spacing: 22) {
                HStack {
                    Text("pairing.title")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("pairing.title.suffix")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                }

                HStack(alignment: .top, spacing: 22) {
                    // 左：本机身份指纹（真实数据，供目视核对）。
                    // 扫码配对（QR / 一次性配对码生成）尚未实现，不展示假占位 QR 与固定码。
                    VStack(spacing: 14) {
                        Text("pairing.thisDevice")
                            .meshTag()
                            .foregroundStyle(MeshDropColor.textMuted)
                        VStack(spacing: 10) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 56, weight: .light))
                                .foregroundStyle(MeshDropColor.textMuted)
                            Text("pairing.qr.developing")
                                .font(MeshDropFont.body(size: 12, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textSecondary)
                            Text("pairing.qr.hint")
                                .font(MeshDropFont.body(size: 11))
                                .foregroundStyle(MeshDropColor.textMuted)
                        }
                        .frame(width: 260, height: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(MeshDropColor.cardBg2)
                        )
                        Text(state.localFingerprintFull)
                            .font(MeshDropFont.mono(size: 13, weight: .semibold))
                            .tracking(1)
                            .foregroundStyle(MeshDropColor.ink)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(MeshDropColor.lime)
                            )
                        Text("pairing.mustMatch")
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
                        Text("pairing.steps.title")
                            .meshTag()
                            .foregroundStyle(MeshDropColor.textMuted)
                        step(1, String(localized: "pairing.step1"))
                        step(2, String(localized: "pairing.step2"))
                        step(3, String(localized: "pairing.step3"))

                        AsciiDivider(text: String(format: String(localized: "pairing.divider.pending"), state.enginePairing == nil ? 0 : 1))

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
                                Text(String(format: String(localized: "pairing.fingerprint.prefix"), p.fingerprint))
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
                                        Text("pairing.reject")
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
                                        Text("pairing.allowRemember")
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
                            Text("pairing.noPending")
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
