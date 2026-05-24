import SwiftUI

private enum GalleryFilter: String, CaseIterable, Hashable {
    case all     = "全部"
    case photos  = "图片"
    case files   = "文件"
    case today   = "今天"

    var english: String {
        switch self {
        case .all:    return "ALL"
        case .photos: return "PHOTOS"
        case .files:  return "FILES"
        case .today:  return "TODAY"
        }
    }
}

struct GalleryPage: View {
    @FocusState private var focusedTile: Int?
    @FocusState private var focusedFilter: GalleryFilter?
    @State private var selectedFilter: GalleryFilter = .all

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 28), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(
                tag: "收件箱 · LIBRARY · \(MockData.gallerySummary.count) 件 · \(MockData.gallerySummary.size)",
                title: "收件箱 ",
                titleAccentSuffix: MockData.gallerySummary.count
            ) {
                HStack(spacing: 12) {
                    ForEach(GalleryFilter.allCases, id: \.self) { f in
                        filterChip(f)
                    }
                }
                .focusSection()
            }

            MeshAsciiDivider(label: "TODAY · 今天 · 7 件 · NEW")
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(MockData.gallery) { item in
                    tile(item)
                }
            }
            .padding(.top, 8)
            .focusSection()

            Spacer(minLength: 0)

            RemoteHint(items: [
                .init(glyph: "↕  ↔︎", label: "选择"),
                .init(glyph: "OK", label: "查看"),
                .init(glyph: "OK·长", label: "更多"),
                .init(glyph: "TV", label: "返回"),
            ])
        }
    }

    @ViewBuilder
    private func filterChip(_ f: GalleryFilter) -> some View {
        let isActive = selectedFilter == f
        let isFocused = focusedFilter == f
        InvisibleFocusButton(isFocused: $focusedFilter, value: f) {
            selectedFilter = f
        } content: {
            HStack(spacing: 6) {
                Text(f.rawValue)
                    .font(.system(size: 18, weight: .bold))
                Text("· \(f.english)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .opacity(0.7)
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundStyle(isActive ? MeshDropColor.ink : MeshDropColor.dpaperDim)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(filterFill(active: isActive, focused: isFocused))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(filterStroke(active: isActive, focused: isFocused), lineWidth: 1.5)
            )
        }
    }

    private func filterFill(active: Bool, focused: Bool) -> Color {
        if active { return MeshDropColor.lime }
        return focused ? MeshDropColor.dink3 : Color.clear
    }
    private func filterStroke(active: Bool, focused: Bool) -> Color {
        if active && focused { return MeshDropColor.ink.opacity(0.45) }
        if focused { return MeshDropColor.dpaper.opacity(0.55) }
        if !active { return MeshDropColor.dline }
        return Color.clear
    }

    @ViewBuilder
    private func tile(_ item: MockData.GalleryItem) -> some View {
        let focused = focusedTile == item.id
        InvisibleFocusButton(isFocused: $focusedTile, value: item.id) { } content: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    if item.kind == "image" {
                        PhotoPlaceholder(hue: item.hue, aspect: 4.0 / 3.0, corner: 18)
                    } else {
                        FileTile(ext: item.ext ?? "FILE", hue: item.hue)
                            .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    }
                    if let badge = item.badge {
                        Text("\(badge) 张")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(MeshDropColor.ink)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(MeshDropColor.lime))
                            .padding(12)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                        .lineLimit(1)
                    Text(item.sub)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MeshDropColor.dpaperMute)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MeshDropColor.dink2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .inset(by: 1)
                    .strokeBorder(MeshDropColor.dline, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .inset(by: 2)
                    .strokeBorder(MeshDropColor.dpaper.opacity(focused ? 0.95 : 0.0), lineWidth: 2.5)
            )
            .animation(.easeInOut(duration: 0.18), value: focused)
        }
    }
}
