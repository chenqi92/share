import SwiftUI

enum ChipTone {
    case mute, lime, ink, outline, flame, sky
}

/// 胶囊标签（COMMON §7.3）。固定高 20，圆角 999。
struct Chip: View {
    let text: String
    var tone: ChipTone = .outline
    var mono: Bool = false
    var leadingDot: Color? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let dot = leadingDot {
                Circle().fill(dot).frame(width: 6, height: 6)
            }
            Text(text)
                .font(mono ? MDFont.chipMono : MDFont.chip)
                .tracking(mono ? 0.8 : 0)
                .textCase(mono ? .uppercase : nil)
        }
        .padding(.horizontal, 10)
        .frame(height: 22)
        .foregroundStyle(fg)
        .background(
            Capsule(style: .continuous)
                .fill(bg)
                .overlay(
                    Capsule(style: .continuous).stroke(border, lineWidth: 0.8)
                )
        )
        .fixedSize()
    }

    private var fg: Color {
        switch tone {
        case .mute:    return MD.dpaper.opacity(0.78)
        case .lime:    return MD.ink
        case .ink:     return MD.paper
        case .outline: return MD.dpaper.opacity(0.78)
        case .flame:   return Color.white
        case .sky:     return MD.ink
        }
    }
    private var bg: Color {
        switch tone {
        case .mute:    return Color.white.opacity(0.06)
        case .lime:    return MD.lime
        case .ink:     return MD.ink
        case .outline: return Color.clear
        case .flame:   return MD.flame
        case .sky:     return MD.sky
        }
    }
    private var border: Color {
        switch tone {
        case .mute, .outline: return Color.white.opacity(0.18)
        case .lime:           return MD.limeDeep.opacity(0.55)
        case .ink:            return Color.white.opacity(0.10)
        case .flame:          return MD.flameDeep.opacity(0.7)
        case .sky:            return MD.sky.opacity(0.6)
        }
    }
}
