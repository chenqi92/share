import SwiftUI

/// Receive Confirmation —— 文件 offer + 文字便签弹框。
struct ReceivePage: View {
    var body: some View {
        ZStack {
            MeshDropColor.background

            // 后景：模糊的 Discovery 缩影
            VStack {
                Radar(devices: MockDevice.all, variant: .sweep, staticTime: 1.0)
                    .frame(width: 480, height: 480)
                    .opacity(0.25)
                    .blur(radius: 6)
            }

            VStack(spacing: 18) {
                Spacer().frame(height: 30)
                HStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MeshDropColor.sky)
                    Text("收到一份传输请求")
                        .font(MeshDropFont.hero(28))
                        .tracking(-0.5)
                        .foregroundStyle(MeshDropColor.textPrimary)
                }

                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        Avatar(initials: "JW", color: Color(hex: 0xC7B8FF),
                               size: 42, ring: true, ringColor: MeshDropColor.sky)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(MockPendingOffer.sample.peer) · \(MockPendingOffer.sample.deviceName)")
                                .font(MeshDropFont.body(size: 14, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textPrimary)
                            HStack(spacing: 5) {
                                Chip(text: "已配对 · Paired", tone: .lime, mono: false)
                                Text(MockPendingOffer.sample.receivedAt)
                                    .font(MeshDropFont.mono(size: 10))
                                    .foregroundStyle(MeshDropColor.textMuted)
                            }
                        }
                        Spacer()
                    }

                    FileChip(name: MockPendingOffer.sample.fileName,
                             size: MockPendingOffer.sample.fileSize,
                             ext: "pages")

                    // 文字便签
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 10, weight: .bold))
                            Text("文字便签 · NOTE")
                                .meshTag()
                        }
                        .foregroundStyle(MeshDropColor.textMuted)

                        Text(MockPendingOffer.sample.note)
                            .font(MeshDropFont.body(size: 13))
                            .foregroundStyle(MeshDropColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(MeshDropColor.cardBg2)
                            )
                    }

                    HStack(spacing: 14) {
                        Text("将存到 ~/Downloads/MeshDrop/嘉伟/")
                            .font(MeshDropFont.mono(size: 10.5))
                            .foregroundStyle(MeshDropColor.textMuted)
                        Spacer()
                        Text("拒绝 · Reject")
                            .font(MeshDropFont.body(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(MeshDropColor.divider, lineWidth: 1)
                            )
                            .foregroundStyle(MeshDropColor.textSecondary)
                        Text("接收 · Accept ⏎")
                            .font(MeshDropFont.body(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(MeshDropColor.lime)
                            )
                            .foregroundStyle(MeshDropColor.ink)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(MeshDropColor.cardBg)
                        .shadow(color: MeshDropColor.ink12, radius: 18, x: 0, y: 6)
                )
                .padding(.horizontal, 80)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
