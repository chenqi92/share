import SwiftUI
import ShareKit

/// 顶部本机信息卡。明显区别于设备列表，避免被误认为是"自己也在列表里"。
struct SelfBanner: View {
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        HStack(spacing: 16) {
            // 本机头像（渐变圆 + 天线 icon）
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
            .shadow(color: .blue.opacity(0.25), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(engine.displayName)
                        .font(.title2.weight(.semibold))
                    Text("（本机）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("正在广播 · 指纹 \(engine.identity.fingerprint.prefix(8))")
                        .font(.caption.weight(.regular))
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(engine.devices.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.tint)
                Text("可见设备")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
    }
}
