import SwiftUI

/// 圆形彩色 + initials；ring=true 时外圈高亮（gaze focus）。
struct Avatar: View {
    let initials: String
    let color: Color
    var size: CGFloat = 36
    var ring: Bool = false
    var ringColor: Color = MD.lime

    var body: some View {
        ZStack {
            if ring {
                Circle()
                    .stroke(ringColor, lineWidth: max(1.5, size * 0.06))
                    .frame(width: size + max(6, size * 0.18), height: size + max(6, size * 0.18))
            }
            Circle()
                .fill(color)
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.5)
                )
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(MD.ink)
        }
        .frame(width: size + (ring ? 12 : 0), height: size + (ring ? 12 : 0))
    }
}
