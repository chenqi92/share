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
    @FocusState private var focusedTab: TVTab?

    var body: some View {
        HStack(alignment: .center, spacing: 36) {
            MeshDropLockup(size: 38)

            Rectangle()
                .fill(MeshDropColor.dline)
                .frame(width: 1, height: 32)

            HStack(spacing: 8) {
                ForEach(TVTab.allCases) { tab in
                    tabPill(tab)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Circle().fill(MeshDropColor.lime).frame(width: 10, height: 10)
                Text("客厅 · LIVING ROOM · 5 台")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(MeshDropColor.dpaperDim)
            }
        }
        .padding(.horizontal, 90)
        .padding(.top, 40)
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private func tabPill(_ tab: TVTab) -> some View {
        let isActive = selection == tab
        let isFocused = focusedTab == tab
        Button {
            selection = tab
        } label: {
            HStack(spacing: 12) {
                Text(tab.rawValue).font(.system(size: 22, weight: .bold))
                Text("· \(tab.english)")
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .opacity(0.65)
            }
            .foregroundStyle(isActive ? MeshDropColor.ink : MeshDropColor.dpaper)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? MeshDropColor.lime : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MeshDropColor.dpaper.opacity(isFocused ? 0.9 : 0.0), lineWidth: 5)
            )
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .animation(.spring(response: 0.30, dampingFraction: 0.78), value: isFocused)
        }
        .buttonStyle(.plain)
        .focused($focusedTab, equals: tab)
    }
}
