import SwiftUI
import MeshDropKit

struct FileOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        Group {
            if let real = engine.pendingFileOffers.first {
                let offer = real.displayMock
                NavigationStack {
                    ZStack {
                        (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

                        VStack(alignment: .leading, spacing: 18) {
                            header(offer, peer: real.peer)

                            AsciiDivider("FILE · 文件")
                            fileCard(offer)

                            if let note = offer.note {
                                AsciiDivider("NOTE · 文字便签")
                                Text(note)
                                    .font(MeshDropFont.body(14))
                                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(scheme == .dark ? MeshDropColor.lime.opacity(0.10) : MeshDropColor.lime.opacity(0.32))
                                    )
                            }

                            AsciiDivider("VERIFY · 验证")
                            verify(real)
                            Spacer()
                            buttons(real)
                        }
                        .padding(20)
                    }
                    .navigationTitle("收件 · Incoming")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Chip("E2E", tone: .lime, mono: true, uppercased: true)
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            } else {
                NavigationStack {
                    VStack(spacing: 10) {
                        Text("没有待审的收件")
                            .font(MeshDropFont.body(14, weight: .semibold))
                        Button("关闭") { dismiss() }
                            .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func header(_ offer: MockPendingOffer, peer: Device) -> some View {
        HStack(spacing: 12) {
            Avatar(initials: Device.initials(peer.name),
                   color: peer.displayMock.color, size: 44, ring: .flame, online: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("来自 \(offer.peer)")
                    .font(MeshDropFont.body(15, weight: .semibold))
                Text(offer.deviceName)
                    .font(MeshDropFont.mono(10.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
            }
            Spacer()
            Text(offer.receivedAt)
                .font(MeshDropFont.mono(10))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
        }
    }

    private func fileCard(_ offer: MockPendingOffer) -> some View {
        let ext = (offer.fileName as NSString).pathExtension
        return HStack(spacing: 14) {
            FileTile(ext: ext.isEmpty ? "?" : ext, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(offer.fileName)
                    .font(MeshDropFont.body(15, weight: .semibold))
                Text(offer.fileSize)
                    .font(MeshDropFont.mono(11))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private func verify(_ offer: PendingFileOffer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("FP")
                    .font(MeshDropFont.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(MeshDropColor.limeDeep)
                Text(offer.peer.humanFingerprint.prefix(23))
                    .font(MeshDropFont.mono(12, weight: .medium))
            }
            HStack {
                Text("SHA")
                    .font(MeshDropFont.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                Text("\(offer.sha256.prefix(16))… · 校验通过后保存 ✓")
                    .font(MeshDropFont.mono(11))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.7) : MeshDropColor.ink80)
            }
        }
    }

    private func buttons(_ offer: PendingFileOffer) -> some View {
        HStack(spacing: 10) {
            Button {
                engine.respondToFileOffer(offer.id, accept: false)
                dismiss()
            } label: {
                Text("拒绝")
                    .font(MeshDropFont.body(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button {
                engine.respondToFileOffer(offer.id, accept: true)
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down")
                    Text("接收")
                }
                .font(MeshDropFont.body(15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(MeshDropColor.lime))
                .foregroundStyle(MeshDropColor.ink)
            }
            .buttonStyle(.plain)
        }
    }
}
