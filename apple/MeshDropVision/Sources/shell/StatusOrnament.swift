import SwiftUI

/// 主窗口顶部 ornament：身份 + 网络 + 指纹缩写 + E2E 标识。
struct StatusOrnament: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Avatar(initials: "我", color: MD.lime, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(MockData.me.name)
                        .font(MDFont.label)
                        .foregroundStyle(MD.dpaper)
                    Text(MockData.me.ip)
                        .font(MDFont.micro).mdMonoTracking()
                        .foregroundStyle(MD.dpaper.opacity(0.55))
                }
            }

            Rectangle().fill(Color.white.opacity(0.12)).frame(width: 0.6, height: 22)

            Chip(text: "VISIBLE · 可见", tone: .lime, mono: true, leadingDot: MD.limeDeep)
            Chip(text: "E2E · CHACHA20", tone: .outline, mono: true)
            Chip(text: "LAN ONLY", tone: .outline, mono: true)

            Spacer().frame(width: 8)

            HStack(spacing: 6) {
                Image(systemName: "fingerprint")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MD.dpaper.opacity(0.6))
                Text(MockData.me.fingerprintShort)
                    .font(MDFont.micro).mdMonoTracking()
                    .foregroundStyle(MD.dpaper.opacity(0.78))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassBackgroundEffect(in: Capsule())
    }
}
