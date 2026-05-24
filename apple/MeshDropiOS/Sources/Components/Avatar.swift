import SwiftUI

/// 圆形彩色 avatar + initials。
/// `ring` 时外圈加一层 lime/flame ring。
public struct Avatar: View {
    public enum Ring { case none, lime, flame, sky }

    let initials: String
    let color: Color
    var size: CGFloat = 32
    var ring: Ring = .none
    var online: Bool = false

    public init(initials: String, color: Color, size: CGFloat = 32, ring: Ring = .none, online: Bool = false) {
        self.initials = initials
        self.color = color
        self.size = size
        self.ring = ring
        self.online = online
    }

    public var body: some View {
        ZStack {
            if ring != .none {
                Circle().stroke(ringColor, lineWidth: 1.5)
                    .frame(width: size + 4, height: size + 4)
            }
            Circle().fill(color)
                .frame(width: size, height: size)
            Text(initials)
                .font(MeshDropFont.display(size * 0.4, weight: .bold))
                .foregroundStyle(MeshDropColor.ink)
                .tracking(-0.5)
            if online {
                Circle().fill(MeshDropColor.lime)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(MeshDropColor.ink.opacity(0.1), lineWidth: 0.5))
                    .offset(x: size * 0.38, y: size * 0.38)
            }
        }
        .frame(width: size + (ring != .none ? 4 : 0), height: size + (ring != .none ? 4 : 0))
    }

    private var ringColor: Color {
        switch ring {
        case .lime:  return MeshDropColor.lime
        case .flame: return MeshDropColor.flame
        case .sky:   return MeshDropColor.sky
        case .none:  return .clear
        }
    }
}
