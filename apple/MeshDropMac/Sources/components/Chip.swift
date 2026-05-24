import SwiftUI

/// 5 种 tone 胶囊标签。固定 height 20pt，radius 999，padding 0/8，font 11pt 600。
enum ChipTone { case mute, lime, ink, outline, flame }

struct Chip: View {
    let text: String
    var tone: ChipTone = .mute
    var mono: Bool = false
    var leading: String? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 5) {
            if let leading {
                Text(leading)
                    .font(MeshDropFont.chip(11, isMono: true))
            }
            Text(text)
                .font(MeshDropFont.chip(11, isMono: mono))
                .tracking(mono ? 0.8 : 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .foregroundStyle(fg)
        .background(bg)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(border, lineWidth: tone == .outline ? 1 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 999))
    }

    private var fg: Color {
        switch tone {
        case .mute:    return MeshDropColor.textSecondary
        case .lime:    return MeshDropColor.ink
        case .ink:     return scheme == .dark ? MeshDropColor.ink : MeshDropColor.paper
        case .outline: return MeshDropColor.textSecondary
        case .flame:   return .white
        }
    }
    private var bg: Color {
        switch tone {
        case .mute:    return MeshDropColor.cardBg2
        case .lime:    return MeshDropColor.lime
        case .ink:     return MeshDropColor.outgoingBubble
        case .outline: return .clear
        case .flame:   return MeshDropColor.flame
        }
    }
    private var border: Color {
        switch tone {
        case .outline: return MeshDropColor.divider
        default:       return .clear
        }
    }
}
