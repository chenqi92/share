import SwiftUI
import MeshDropKit

struct PairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let pending = engine.pendingPairings.first {
                            header(pending)
                            AsciiDivider(MD("pairing.fingerprintSection"))
                            fingerprint(pending.peer.humanFingerprint)
                            AsciiDivider(MD("pairing.stepsSection"))
                            steps
                            actions(pending.id)
                        } else {
                            empty
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(MD("pairing.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(MD("common.done")) { dismiss() }
                }
            }
        }
    }

    private func header(_ req: PairingRequest) -> some View {
        let mock = req.peer.displayMock
        return HStack(spacing: 12) {
            Avatar(initials: mock.initials, color: mock.color, size: 44, ring: .lime, online: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(MD("pairing.wantsToPair", req.peer.name))
                    .font(MeshDropFont.body(15, weight: .semibold))
                Text(req.peer.model ?? req.peer.name)
                    .font(MeshDropFont.mono(10.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
            }
            Spacer()
            Chip("LIVE", tone: .lime, mono: true, uppercased: true, icon: "circle.fill")
        }
    }

    private func fingerprint(_ fp: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fp)
                .font(MeshDropFont.mono(13, weight: .medium))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
            Text(MD("pairing.fingerprint.hint"))
                .font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow(1, MD("pairing.step1"))
            stepRow(2, MD("pairing.step2"))
            stepRow(3, MD("pairing.step3"))
        }
    }

    private func stepRow(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)")
                .font(MeshDropFont.mono(13, weight: .bold))
                .frame(width: 24, height: 24)
                .background(Circle().fill(MeshDropColor.lime))
                .foregroundStyle(MeshDropColor.ink)
            Text(text)
                .font(MeshDropFont.body(14))
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Text(MD("pairing.empty.title"))
                .font(MeshDropFont.body(14, weight: .semibold))
            Text(MD("pairing.empty.subtitle"))
                .font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func actions(_ requestID: UUID) -> some View {
        HStack(spacing: 10) {
            Button {
                engine.respondToPairing(requestID, decision: .reject)
                dismiss()
            } label: {
                Text(MD("common.reject"))
                    .font(MeshDropFont.body(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .overlay(Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            Button {
                engine.respondToPairing(requestID, decision: .trust)
                dismiss()
            } label: {
                Text(MD("pairing.primary.trust"))
                    .font(MeshDropFont.body(15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(MeshDropColor.lime))
                    .foregroundStyle(MeshDropColor.ink)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }
}
