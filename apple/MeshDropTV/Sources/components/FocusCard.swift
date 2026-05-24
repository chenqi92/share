import SwiftUI

/// 标准可聚焦卡：focus 时 inset 内描边 + 小幅 lift（offset y）+ 极小 scale，不溢出。
struct FocusCard<Content: View>: View {
    var corner: CGFloat = 22
    var padding: CGFloat = 0
    @ViewBuilder var content: () -> Content

    @FocusState private var focused: Bool

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(MeshDropColor.dink2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .inset(by: 1)
                    .strokeBorder(MeshDropColor.dline, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .inset(by: 2)
                    .strokeBorder(MeshDropColor.dpaper.opacity(focused ? 0.85 : 0.0), lineWidth: 2.5)
            )
            .offset(y: focused ? -4 : 0)
            .animation(.spring(response: 0.30, dampingFraction: 0.82), value: focused)
            .focusable(true)
            .focused($focused)
            .focusEffectDisabled()
    }
}

/// CTA 大按钮：lime 底 + ink 字；focus 时 inset ring + 小幅 lift。
struct CTAButton: View {
    var title: String
    var subtitle: String? = nil
    var tone: ChipTone = .lime
    var fillWidth: Bool = false
    var action: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(fg)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .tracking(1.3)
                            .textCase(.uppercase)
                            .foregroundStyle(fg.opacity(0.65))
                    }
                }
                if fillWidth { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 22)
            .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .inset(by: 2)
                    .strokeBorder(ringColor.opacity(focused ? 0.95 : 0.0), lineWidth: 3)
            )
            .offset(y: focused ? -4 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: focused)
        }
        .buttonStyle(.plain)
        .focused($focused)
        .focusEffectDisabled()
    }

    private var bg: Color {
        switch tone {
        case .lime: return MeshDropColor.lime
        case .ink:  return MeshDropColor.dink3
        case .flame: return MeshDropColor.flame
        case .sky: return MeshDropColor.sky
        case .mute: return MeshDropColor.dink2
        case .outline: return Color.clear
        }
    }
    private var fg: Color {
        switch tone {
        case .lime, .sky: return MeshDropColor.ink
        case .ink: return MeshDropColor.dpaper
        case .mute: return MeshDropColor.dpaperDim
        case .flame: return .white
        case .outline: return MeshDropColor.dpaper
        }
    }
    private var ringColor: Color {
        switch tone {
        case .lime, .sky: return MeshDropColor.ink
        default: return MeshDropColor.dpaper
        }
    }
}
