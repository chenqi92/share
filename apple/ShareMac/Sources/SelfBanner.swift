import SwiftUI
import ShareKit

/// 顶部本机信息卡。Liquid Glass 容器，区别于设备列表。
struct SelfBanner: View {
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        HStack(spacing: 16) {
            // 本机头像
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 56, height: 56)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(engine.displayName)
                        .font(.title3.weight(.semibold))
                    Text("本机")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.85)))
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("正在广播 · 指纹 \(engine.identity.fingerprint.prefix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(engine.devices.count)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                Text("可见设备")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 18, y: 6)
    }
}
