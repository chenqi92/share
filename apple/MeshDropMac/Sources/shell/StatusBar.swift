import SwiftUI

/// 底部 mono 状态条。
struct StatusBar: View {
    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(MeshDropColor.limeDeep)
                .frame(width: 6, height: 6)
            Text("LAN ONLINE")
                .meshTag()
                .foregroundStyle(MeshDropColor.limeDeep)
            Divider().frame(height: 12)
            Text("\(MockMe.ip)/24")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
            Divider().frame(height: 12)
            Text("mDNS · _meshdrop._tcp")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
            Spacer()
            Text("E2E · X25519+ChaCha20")
                .meshTag()
                .foregroundStyle(MeshDropColor.textSecondary)
            Divider().frame(height: 12)
            Text("FP \(MockMe.fingerprint)")
                .font(MeshDropFont.mono(size: 10))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Rectangle()
                .fill(MeshDropColor.cardBg)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(MeshDropColor.divider),
                    alignment: .top
                )
        )
    }
}
