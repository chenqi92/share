import SwiftUI

struct FileOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let offer = Mock.pendingOffer

        NavigationStack {
            ZStack {
                (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    header(offer)

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
                    verify(offer)
                    Spacer()
                    buttons
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
    }

    private func header(_ offer: MockPendingOffer) -> some View {
        HStack(spacing: 12) {
            Avatar(initials: "JW", color: Color(red: 0.78, green: 0.72, blue: 1.0), size: 44, ring: .flame, online: true)
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
        HStack(spacing: 14) {
            FileTile(ext: "pages", size: 56)
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

    private func verify(_ offer: MockPendingOffer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("FP")
                    .font(MeshDropFont.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(MeshDropColor.limeDeep)
                Text("ZX8K · L72M · 9FQ3 · 7HD2")
                    .font(MeshDropFont.mono(12, weight: .medium))
            }
            HStack {
                Text("SHA")
                    .font(MeshDropFont.mono(10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                Text("校验通过后保存 ✓")
                    .font(MeshDropFont.body(12))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.7) : MeshDropColor.ink80)
            }
        }
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("拒绝")
                    .font(MeshDropFont.body(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button { dismiss() } label: {
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
