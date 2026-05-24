import SwiftUI
import ShareKit

/// 顶部本机信息卡。明确"（本机）"徽标避免与设备列表混淆。
struct SelfCard: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.horizontalSizeClass) var hSize

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: avatarSize, height: avatarSize)
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(engine.displayName)
                        .font(hSize == .regular ? .title2.weight(.semibold) : .headline)
                        .lineLimit(1)
                    Text("本机")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.blue.opacity(0.85)))
                }
                HStack(spacing: 6) {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text("正在广播 · \(engine.identity.fingerprint.prefix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospaced()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(hSize == .regular ? 20 : 16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var avatarSize: CGFloat { hSize == .regular ? 56 : 48 }
    private var iconSize: CGFloat { hSize == .regular ? 24 : 20 }
}
