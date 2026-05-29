import SwiftUI

/// 跨所有 tab 的全局浮层：
/// - 配对请求到达 → 居中模态卡片（必须显式接受 / 拒绝）
/// - 文件 offer 到达 → 居中模态卡片（接收 / 拒绝）
///
/// 配对优先于 offer：通常要先信任对端，文件 offer 才会进来。
/// 网络层错误由底部 StatusBar 展示，这里不重复。
struct GlobalOverlay: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        ZStack {
            if let pairing = state.enginePairing {
                scrim
                pairingCard(pairing)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else if let offer = state.engineOffer {
                scrim
                offerCard(offer)
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: state.enginePairing?.id)
        .animation(.easeOut(duration: 0.18), value: state.engineOffer?.id)
    }

    private var scrim: some View {
        Rectangle()
            .fill(Color.black.opacity(0.42))
            .ignoresSafeArea()
    }

    // MARK: - 配对请求

    private func pairingCard(_ p: MockPendingPairing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "person.2.badge.key")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MeshDropColor.limeDeep)
                Text("配对请求 · Pairing")
                    .font(MeshDropFont.body(size: 16, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Spacer()
                Text(p.receivedAt)
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }

            HStack(spacing: 10) {
                Avatar(initials: String(p.peer.prefix(2)), color: Color(hex: 0xFFB4A1), size: 38, ring: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(p.deviceName)
                        .font(MeshDropFont.body(size: 13.5, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text(p.peer)
                        .font(MeshDropFont.mono(size: 10.5))
                        .foregroundStyle(MeshDropColor.textMuted)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("对比指纹 · 两端目视一致")
                    .meshTag()
                    .foregroundStyle(MeshDropColor.textMuted)
                Text(p.fingerprint)
                    .font(MeshDropFont.mono(size: 11.5))
                    .foregroundStyle(MeshDropColor.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(MeshDropColor.cardBg2)
                    )
            }

            HStack(spacing: 10) {
                Spacer()
                pillButton("拒绝 · Reject", filled: false) { state.rejectCurrentPairing() }
                pillButton("仅本次", filled: false) { state.acceptCurrentPairing(trust: false) }
                pillButton("允许并记住", filled: true) { state.acceptCurrentPairing(trust: true) }
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(modalBackground)
    }

    // MARK: - 文件 offer

    private func offerCard(_ offer: MockPendingOffer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MeshDropColor.sky)
                Text("收到传输请求 · Incoming")
                    .font(MeshDropFont.body(size: 16, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Spacer()
                Text(offer.receivedAt)
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }

            HStack(spacing: 10) {
                Avatar(initials: String(offer.peer.prefix(2)), color: Color(hex: 0xC7B8FF),
                       size: 38, ring: true, ringColor: MeshDropColor.sky)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(offer.peer) · \(offer.deviceName)")
                        .font(MeshDropFont.body(size: 13.5, weight: .semibold))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("将存到 ~/Documents/MeshDrop/\(offer.peer)/")
                        .font(MeshDropFont.mono(size: 10))
                        .foregroundStyle(MeshDropColor.textMuted)
                }
                Spacer()
            }

            FileChip(name: offer.fileName,
                     size: offer.fileSize,
                     ext: (offer.fileName as NSString).pathExtension.lowercased())

            HStack(spacing: 10) {
                Spacer()
                pillButton("拒绝 · Reject", filled: false) { state.rejectCurrentOffer() }
                pillButton("接收 · Accept", filled: true) { state.acceptCurrentOffer() }
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(modalBackground)
    }

    // MARK: - 复用

    private var modalBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(MeshDropColor.cardBg)
            .shadow(color: MeshDropColor.ink12, radius: 24, x: 0, y: 10)
    }

    @ViewBuilder
    private func pillButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MeshDropFont.body(size: 12.5, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if filled {
                            RoundedRectangle(cornerRadius: 9).fill(MeshDropColor.lime)
                        } else {
                            RoundedRectangle(cornerRadius: 9).stroke(MeshDropColor.divider, lineWidth: 1)
                        }
                    }
                )
                .foregroundStyle(filled ? MeshDropColor.ink : MeshDropColor.textSecondary)
        }
        .buttonStyle(.plain)
    }
}
