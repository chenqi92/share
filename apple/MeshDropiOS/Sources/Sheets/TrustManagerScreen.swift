import SwiftUI

struct TrustManagerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    AsciiDivider("PAIRED · 已配对 · \(Mock.trusted.count)")
                    ForEach(Mock.trusted) { row($0) }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .navigationTitle("信任 · Trust")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("完成") { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("信任管理")
                .font(MeshDropFont.display(24, weight: .bold))
            Text("已配对设备的指纹与最近活动")
                .font(MeshDropFont.body(13))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
    }

    private func row(_ t: MockTrustedPeer) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(t.name)
                    .font(MeshDropFont.body(15, weight: .semibold))
                Text(t.device)
                    .font(MeshDropFont.mono(10.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                Spacer()
                Chip("TRUSTED", tone: .lime, mono: true, uppercased: true)
            }
            Text(t.fingerprint)
                .font(MeshDropFont.mono(12, weight: .medium))
            HStack(spacing: 12) {
                Label(t.firstSeen, systemImage: "calendar")
                    .labelStyle(.titleAndIcon)
                    .font(MeshDropFont.mono(10.5))
                Label(t.lastSeen, systemImage: "clock")
                    .labelStyle(.titleAndIcon)
                    .font(MeshDropFont.mono(10.5))
                Spacer()
                Button {} label: {
                    Text("撤销").font(MeshDropFont.body(12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .foregroundStyle(MeshDropColor.error)
                        .overlay(Capsule().strokeBorder(MeshDropColor.error, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }
}
