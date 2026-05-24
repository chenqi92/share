import SwiftUI

enum ChipTone {
    case mute, lime, ink, outline, flame, sky
}

struct Chip: View {
    var text: String
    var tone: ChipTone = .outline
    var mono: Bool = true
    var size: CGFloat = 22

    var body: some View {
        Text(text)
            .font(font)
            .tracking(mono ? 1.6 : 0.4)
            .textCase(mono ? .uppercase : nil)
            .foregroundStyle(fg)
            .padding(.horizontal, size * 0.7)
            .padding(.vertical, size * 0.32)
            .background(
                Capsule(style: .continuous)
                    .fill(bg)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(stroke, lineWidth: 1.5)
            )
            .fixedSize(horizontal: true, vertical: true)
    }

    private var font: Font {
        mono
            ? .system(size: size, weight: .bold, design: .monospaced)
            : .system(size: size, weight: .semibold, design: .default)
    }
    private var fg: Color {
        switch tone {
        case .mute:    return MeshDropColor.dpaperDim
        case .lime:    return MeshDropColor.ink
        case .ink:     return MeshDropColor.dpaper
        case .outline: return MeshDropColor.dpaperDim
        case .flame:   return .white
        case .sky:     return MeshDropColor.ink
        }
    }
    private var bg: Color {
        switch tone {
        case .mute:    return MeshDropColor.dink3.opacity(0.6)
        case .lime:    return MeshDropColor.lime
        case .ink:     return MeshDropColor.ink
        case .outline: return Color.clear
        case .flame:   return MeshDropColor.flame
        case .sky:     return MeshDropColor.sky
        }
    }
    private var stroke: Color {
        switch tone {
        case .outline: return MeshDropColor.dline
        case .mute:    return MeshDropColor.dlineSoft
        default:       return Color.clear
        }
    }
}
