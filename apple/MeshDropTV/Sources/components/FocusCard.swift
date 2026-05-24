import SwiftUI

/// 标准可聚焦卡：scale 1.05 + 6px ring，3 米外可辨。
struct FocusCard<Content: View>: View {
    var corner: CGFloat = 22
    var padding: CGFloat = 0
    @ViewBuilder var content: () -> Content

    @Environment(\.isFocused) private var isFocused
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
                    .stroke(MeshDropColor.dline, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(MeshDropColor.dpaper.opacity(focused ? 0.85 : 0.0), lineWidth: 6)
                    .blur(radius: 0.5)
            )
            .scaleEffect(focused ? 1.05 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: focused)
            .focusable(true)
            .focused($focused)
    }
}

/// CTA 大按钮：lime 底 + ink 字，focus 时 ring + scale。
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
                            .font(.system(size: 16, weight: .semibold, design: .monospaced))
                            .tracking(1.4)
                            .textCase(.uppercase)
                            .foregroundStyle(fg.opacity(0.7))
                    }
                }
                if fillWidth { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 22)
            .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MeshDropColor.dpaper.opacity(focused ? 0.95 : 0.0), lineWidth: 6)
            )
            .scaleEffect(focused ? 1.06 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: focused)
        }
        .buttonStyle(.plain)
        .focused($focused)
    }

    private var bg: Color {
        switch tone {
        case .lime: return MeshDropColor.lime
        case .ink:  return MeshDropColor.ink
        case .flame: return MeshDropColor.flame
        case .sky: return MeshDropColor.sky
        case .mute: return MeshDropColor.dink3
        case .outline: return Color.clear
        }
    }
    private var fg: Color {
        switch tone {
        case .lime, .sky: return MeshDropColor.ink
        case .ink, .mute: return MeshDropColor.dpaper
        case .flame: return .white
        case .outline: return MeshDropColor.dpaper
        }
    }
}
