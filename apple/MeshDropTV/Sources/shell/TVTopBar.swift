import SwiftUI

enum TVTab: String, CaseIterable, Identifiable {
    case receive  = "接收"
    case nearby   = "附近"
    case gallery  = "收件箱"
    case pairing  = "配对"
    case settings = "设置"

    var id: String { rawValue }
    var english: String {
        switch self {
        case .receive:  return "Receive"
        case .nearby:   return "Nearby"
        case .gallery:  return "Library"
        case .pairing:  return "Pair"
        case .settings: return "Settings"
        }
    }
}

struct TVTopBar: View {
    @Binding var selection: TVTab
    var deviceCount: Int = 0
    @FocusState private var focusedTab: TVTab?

    var body: some View {
        HStack(alignment: .center, spacing: 44) {
            MeshDropLockup(size: 38)

            Rectangle()
                .fill(MeshDropColor.dline)
                .frame(width: 1, height: 32)

            HStack(spacing: 20) {
                ForEach(TVTab.allCases) { tab in
                    tabPill(tab)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Circle()
                    .fill(deviceCount > 0 ? MeshDropColor.lime : MeshDropColor.dpaperMute)
                    .frame(width: 10, height: 10)
                Text(statusLabel)
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(MeshDropColor.dpaperDim)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 90)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var statusLabel: String {
        if deviceCount == 0 { return "客厅 · LIVING ROOM · 扫描中" }
        return "客厅 · LIVING ROOM · \(deviceCount) 台"
    }

    @ViewBuilder
    private func tabPill(_ tab: TVTab) -> some View {
        let isActive = selection == tab
        let isFocused = focusedTab == tab

        InvisibleFocusButton(isFocused: $focusedTab, value: tab) {
            selection = tab
        } content: {
            HStack(spacing: 10) {
                Text(tab.rawValue)
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("· \(tab.english)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .opacity(0.55)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(textColor(isActive: isActive, isFocused: isFocused))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fillColor(isActive: isActive, isFocused: isFocused))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .inset(by: 1)
                    .strokeBorder(strokeColor(isActive: isActive, isFocused: isFocused), lineWidth: 2)
            )
        }
    }

    private func textColor(isActive: Bool, isFocused: Bool) -> Color {
        if isActive { return MeshDropColor.ink }
        return isFocused ? MeshDropColor.dpaper : MeshDropColor.dpaperDim
    }

    private func fillColor(isActive: Bool, isFocused: Bool) -> Color {
        if isActive { return MeshDropColor.lime }
        return isFocused ? MeshDropColor.dink3 : Color.clear
    }

    private func strokeColor(isActive: Bool, isFocused: Bool) -> Color {
        if isActive && isFocused { return MeshDropColor.ink.opacity(0.45) }
        if isFocused { return MeshDropColor.dpaper.opacity(0.55) }
        return Color.clear
    }
}
