import SwiftUI
import MeshDropKit

struct TrustManagerScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var engine: ShareEngine

    private var trusted: [(record: TrustRecord, display: MockTrustedPeer)] {
        engine.trusted.map { ($0, $0.displayMock) }
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    AsciiDivider(MD("trust.paired.section", trusted.count))
                    if trusted.isEmpty {
                        empty
                    } else {
                        ForEach(trusted, id: \.record.id) { item in
                            row(item.display, fingerprint: item.record.fingerprint)
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .navigationTitle(MD("trust.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(MD("common.done")) { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(MD("trust.header.title"))
                .font(MeshDropFont.display(24, weight: .bold))
            Text(MD("trust.header.subtitle"))
                .font(MeshDropFont.body(13))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text(MD("trust.empty.title"))
                .font(MeshDropFont.body(13.5, weight: .semibold))
            Text(MD("trust.empty.subtitle"))
                .font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity, minHeight: 140)
    }

    private func row(_ t: MockTrustedPeer, fingerprint: String) -> some View {
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
                Button {
                    engine.revokeTrust(fingerprint: fingerprint)
                } label: {
                    Text(MD("trust.revoke")).font(MeshDropFont.body(12, weight: .semibold))
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
