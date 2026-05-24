import SwiftUI

/// 圆形彩色 + initials 字符。size 28/32/36/40/48；ring=true 时外圈 lime/flame。
struct Avatar: View {
    let initials: String
    let color: Color
    var size: CGFloat = 32
    var ring: Bool = false
    var ringColor: Color = MeshDropColor.lime

    var body: some View {
        ZStack {
            if ring {
                Circle()
                    .stroke(ringColor, lineWidth: 2)
                    .frame(width: size + 6, height: size + 6)
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text(initials)
                .font(MeshDropFont.display(size: size * 0.42, weight: .bold))
                .foregroundStyle(MeshDropColor.ink)
        }
        .frame(width: size + (ring ? 8 : 0), height: size + (ring ? 8 : 0))
    }
}
