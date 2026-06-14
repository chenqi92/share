import SwiftUI

/// Receive Confirmation —— 文件 offer + 文字便签弹框。
struct ReceivePage: View {
    @EnvironmentObject var state: AppState
    private var screenshotTime: Double? {
        ProcessInfo.processInfo.environment["MESHDROP_SCREENSHOT"] == "1" ? 1.0 : nil
    }

    var body: some View {
        ZStack {
            MeshDropColor.background

            VStack {
                Radar(devices: state.engineDevices, variant: .sweep, staticTime: screenshotTime)
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
                    Text(state.engineOffer == nil ? "receive.empty.title" : "receive.title")
                        .font(MeshDropFont.hero(28))
                        .tracking(-0.5)
                        .foregroundStyle(MeshDropColor.textPrimary)
                }

                if let offer = state.engineOffer {
                    offerCard(offer)
                } else {
                    Text("receive.empty.detail")
                        .font(MeshDropFont.body(size: 12))
                        .foregroundStyle(MeshDropColor.textMuted)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(MeshDropColor.cardBg)
                        )
                        .padding(.horizontal, 80)
                }

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func offerCard(_ offer: MockPendingOffer) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Avatar(initials: String(offer.peer.prefix(2)), color: Color(hex: 0xC7B8FF),
                       size: 42, ring: true, ringColor: MeshDropColor.sky)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(offer.peer) · \(offer.deviceName)")
                        .font(MeshDropFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    HStack(spacing: 5) {
                        Chip(text: String(localized: "receive.paired"), tone: .lime, mono: false)
                        Text(offer.receivedAt)
                            .font(MeshDropFont.mono(size: 10))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                }
                Spacer()
            }

            offerPreview(offer)

            HStack(spacing: 14) {
                Text(String(format: String(localized: "receive.saveTo"), offer.peer))
                    .font(MeshDropFont.mono(size: 10.5))
                    .foregroundStyle(MeshDropColor.textMuted)
                Spacer()
                Button { state.rejectCurrentOffer() } label: {
                    Text("receive.reject")
                        .font(MeshDropFont.body(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(MeshDropColor.divider, lineWidth: 1)
                        )
                        .foregroundStyle(MeshDropColor.textSecondary)
                }
                .buttonStyle(.plain)
                Button { state.acceptCurrentOffer() } label: {
                    Text("receive.accept")
                        .font(MeshDropFont.body(size: 13, weight: .semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(MeshDropColor.lime)
                        )
                        .foregroundStyle(MeshDropColor.ink)
                }
                .buttonStyle(.plain)
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
    }

    @ViewBuilder
    private func offerPreview(_ offer: MockPendingOffer) -> some View {
        if offer.isImage {
            ImagePreview(url: nil, base64: offer.previewBase64, cornerRadius: 14)
                .frame(height: 240)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(offer.fileName)
                            .font(MeshDropFont.body(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text(offer.fileSize)
                            .font(MeshDropFont.mono(size: 10.5))
                            .opacity(0.8)
                    }
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.black.opacity(0.62), .black.opacity(0.12)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                }
        } else {
            FileChip(name: offer.fileName,
                     size: offer.fileSize,
                     ext: (offer.fileName as NSString).pathExtension.lowercased())
        }
    }
}
