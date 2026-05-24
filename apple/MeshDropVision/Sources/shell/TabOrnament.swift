import SwiftUI

/// 底部 ornament tab：附近 / 对话 / 传输 / 配对（实质 1 个胶囊 + 4 个 button）。
struct TabOrnament: View {
    @Binding var current: AppTab

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    current = tab
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.label)
                            .font(MDFont.label)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minWidth: 110)
                    .background(
                        Capsule()
                            .fill(current == tab ? MD.lime.opacity(0.18) : .clear)
                            .overlay(
                                Capsule().stroke(
                                    current == tab ? MD.lime.opacity(0.55) : .clear,
                                    lineWidth: 1)
                            )
                    )
                    .foregroundStyle(current == tab ? MD.lime : MD.dpaper.opacity(0.75))
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassBackgroundEffect(in: Capsule())
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case nearby, chats, transfers, pairing
    var id: String { rawValue }
    var label: String {
        switch self {
        case .nearby:    return "附近 · Nearby"
        case .chats:     return "对话 · Chats"
        case .transfers: return "传输 · Transfers"
        case .pairing:   return "配对 · Pair"
        }
    }
    var systemImage: String {
        switch self {
        case .nearby:    return "dot.radiowaves.left.and.right"
        case .chats:     return "bubble.left.and.bubble.right"
        case .transfers: return "arrow.up.arrow.down"
        case .pairing:   return "qrcode"
        }
    }
}
