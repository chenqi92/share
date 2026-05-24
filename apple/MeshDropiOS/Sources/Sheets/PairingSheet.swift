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
                            AsciiDivider("FINGERPRINT · 指纹")
                            fingerprint(pending.peer.humanFingerprint)
                            AsciiDivider("STEPS · 三步")
                            steps
                            actions(pending.id)
                        } else {
                            empty
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("配对 · Pairing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func header(_ req: PairingRequest) -> some View {
        let mock = req.peer.displayMock
        return HStack(spacing: 12) {
            Avatar(initials: mock.initials, color: mock.color, size: 44, ring: .lime, online: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(req.peer.name) 想配对")
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
            Text("对端 MeshDrop 设置里也能看到相同的指纹。两边一致才允许。")
                .font(MeshDropFont.mono(11))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow(1, "在对端设备上确认 MeshDrop 已可见")
            stepRow(2, "对比上方指纹首两组")
            stepRow(3, "允许后下次自动放行")
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
            Text("当前没有待配对的设备")
                .font(MeshDropFont.body(14, weight: .semibold))
            Text("对端发起连接时会出现在这里")
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
                Text("拒绝")
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
                Text("允许并记住")
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
