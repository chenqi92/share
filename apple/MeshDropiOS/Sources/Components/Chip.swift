import SwiftUI

/// 5 种 tone 的胶囊标签（高度固定 20，radius 999，padding 0/8）。
public struct Chip: View {
    public enum Tone { case mute, lime, ink, outline, flame, sky }

    let text: String
    var tone: Tone = .mute
    var mono: Bool = false
    var uppercased: Bool = false
    var icon: String? = nil

    @Environment(\.colorScheme) private var scheme

    public init(_ text: String, tone: Tone = .mute, mono: Bool = false,
                uppercased: Bool = false, icon: String? = nil) {
        self.text = text
        self.tone = tone
        self.mono = mono
        self.uppercased = uppercased
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(uppercased ? text.uppercased() : text)
                .font(mono ? MeshDropFont.chipMono : MeshDropFont.chipText)
                .tracking(uppercased ? 1.5 : 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 20)
        .foregroundStyle(textColor)
        .background(backgroundShape)
        .overlay(borderShape)
    }

    private var textColor: Color {
        switch tone {
        case .mute:    return scheme == .dark ? Color.white.opacity(0.65) : MeshDropColor.ink60
        case .lime:    return MeshDropColor.ink
        case .ink:     return scheme == .dark ? MeshDropColor.ink : MeshDropColor.paper
        case .outline: return scheme == .dark ? Color.white.opacity(0.65) : MeshDropColor.ink60
        case .flame:   return .white
        case .sky:     return .white
        }
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch tone {
        case .mute:
            Capsule().fill(scheme == .dark ? Color.white.opacity(0.08) : MeshDropColor.ink06)
        case .lime:
            Capsule().fill(MeshDropColor.lime)
        case .ink:
            Capsule().fill(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
        case .outline:
            Capsule().fill(Color.clear)
        case .flame:
            Capsule().fill(MeshDropColor.flame)
        case .sky:
            Capsule().fill(MeshDropColor.sky)
        }
    }

    @ViewBuilder
    private var borderShape: some View {
        if tone == .outline {
            Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1)
        }
    }
}
