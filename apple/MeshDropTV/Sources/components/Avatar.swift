import SwiftUI

struct Avatar: View {
    var initials: String
    var color: Color
    var size: CGFloat = 56
    var ring: Color? = nil

    var body: some View {
        ZStack {
            if let ring {
                Circle()
                    .stroke(ring, lineWidth: max(2, size * 0.06))
                    .frame(width: size + size * 0.18, height: size + size * 0.18)
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(MeshDropColor.ink)
                )
        }
        .frame(width: size + size * 0.18, height: size + size * 0.18)
    }
}
