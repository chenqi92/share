import SwiftUI

struct PairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            ZStack {
                (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        AsciiDivider("CODE · 6 字符代码")
                        bigCode
                        AsciiDivider("FINGERPRINT · 指纹")
                        fingerprint
                        AsciiDivider("STEPS · 三步")
                        steps
                        actions
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

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(initials: "LL", color: Color(red: 1.0, green: 0.70, blue: 0.63), size: 44, ring: .lime, online: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Mock.pendingPairing.peer) 想配对")
                    .font(MeshDropFont.body(15, weight: .semibold))
                Text(Mock.pendingPairing.deviceName)
                    .font(MeshDropFont.mono(10.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
            }
            Spacer()
            Chip("LIVE", tone: .lime, mono: true, uppercased: true, icon: "circle.fill")
        }
    }

    private var bigCode: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                ForEach(Array("QX8K7L"), id: \.self) { ch in
                    Text(String(ch))
                        .font(MeshDropFont.display(40, weight: .bold))
                        .tracking(0.5)
                        .frame(width: 44, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
                        )
                }
            }
            Text("对端屏幕应当显示与此一致的 6 字符代码")
                .font(MeshDropFont.body(12))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity)
    }

    private var fingerprint: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                qrPlaceholder
                Text(Mock.pendingPairing.fingerprint)
                    .font(MeshDropFont.mono(13, weight: .medium))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
            }
        }
    }

    private var qrPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                .frame(width: 90, height: 90)
            // 假 QR：8x8 黑白方阵
            VStack(spacing: 2) {
                ForEach(0..<8) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<8) { col in
                            Rectangle()
                                .fill(((row * 7 + col * 3) % 3 == 0) ?
                                      (scheme == .dark ? MeshDropColor.ink : Color.white) :
                                        .clear)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .frame(width: 78, height: 78)
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepRow(1, "对端设备显示相同代码")
            stepRow(2, "确认指纹首两组")
            stepRow(3, "允许并记住该设备")
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

    private var actions: some View {
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
