import SwiftUI
import MeshDropKit

private enum GalleryFilter: String, CaseIterable, Hashable {
    case all
    case photos
    case files

    /// 本地化的过滤器中文 / 英文名。
    var localizedName: String {
        switch self {
        case .all:    return L10n.galleryFilterAll
        case .photos: return L10n.galleryFilterPhotos
        case .files:  return L10n.galleryFilterFiles
        }
    }
    var english: String {
        switch self {
        case .all:    return L10n.galleryFilterAllEn
        case .photos: return L10n.galleryFilterPhotosEn
        case .files:  return L10n.galleryFilterFilesEn
        }
    }
}

struct GalleryPage: View {
    @EnvironmentObject private var engine: ShareEngine
    @FocusState private var focusedTile: UUID?
    @FocusState private var focusedFilter: GalleryFilter?
    @State private var selectedFilter: GalleryFilter = .all

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 28), count: 5)

    var body: some View {
        let inbox = engine.history.filter { $0.isInboxFile }
        let filtered = inbox.filter(matches)

        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ForEach(GalleryFilter.allCases, id: \.self) { f in
                    filterChip(f)
                }
                Spacer()
                Text(L10n.galleryCount(filtered.count))
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaperMute)
            }
            .padding(.top, 4)

            MeshAsciiDivider(label: inbox.isEmpty ? L10n.galleryDividerInboxEmpty : L10n.galleryDividerInbox)
                .padding(.top, 4)

            if filtered.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 28) {
                        ForEach(filtered) { item in
                            tile(item)
                        }
                    }
                    .padding(.top, 8)
                }
                .focusSection()
            }

            Spacer(minLength: 0)

            RemoteHint(items: [
                .init(glyph: "↕  ↔︎", label: L10n.hintSelect),
                .init(glyph: "OK", label: L10n.hintView),
                .init(glyph: "TV", label: L10n.hintReturn),
            ])
        }
    }

    private func matches(_ item: HistoryItem) -> Bool {
        switch selectedFilter {
        case .all:    return true
        case .photos: return isImageName(fileName(of: item))
        case .files:  return !isImageName(fileName(of: item))
        }
    }

    private func fileName(of item: HistoryItem) -> String {
        if case .file(let name, _, _) = item.kind { return name }
        return ""
    }

    private func fileSize(of item: HistoryItem) -> UInt64 {
        if case .file(_, let size, _) = item.kind { return size }
        return 0
    }

    private func isImageName(_ name: String) -> Bool {
        let ext = (name as NSString).pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tiff", "bmp"].contains(ext)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text(L10n.galleryEmptyTag)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(MeshDropColor.dpaperMute)
            Text(L10n.galleryEmptyBody)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MeshDropColor.dpaperDim)
        }
        .frame(maxWidth: .infinity, maxHeight: 280)
    }

    @ViewBuilder
    private func filterChip(_ f: GalleryFilter) -> some View {
        let isActive = selectedFilter == f
        let isFocused = focusedFilter == f
        InvisibleFocusButton(isFocused: $focusedFilter, value: f) {
            selectedFilter = f
        } content: {
            HStack(spacing: 6) {
                Text(f.localizedName)
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
    private func tile(_ item: HistoryItem) -> some View {
        let focused = focusedTile == item.id
        let name = fileName(of: item)
        let isImage = isImageName(name)
        let hue = hueFromName(name)
        InvisibleFocusButton(isFocused: $focusedTile, value: item.id) { } content: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    if isImage {
                        PhotoPlaceholder(hue: hue, aspect: 4.0 / 3.0, corner: 18)
                    } else {
                        FileTile(ext: ext(of: name), hue: hue)
                            .aspectRatio(4.0 / 3.0, contentMode: .fit)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(name.isEmpty ? L10n.galleryUnnamed : name)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                        .lineLimit(1)
                    Text(subtitle(for: item))
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

    private func ext(of name: String) -> String {
        let e = (name as NSString).pathExtension
        return e.isEmpty ? "FILE" : e.uppercased()
    }

    private func subtitle(for item: HistoryItem) -> String {
        let peer = item.peer.name
        let size = ByteCountFormatter.string(fromByteCount: Int64(fileSize(of: item)), countStyle: .file)
        return "\(peer) · \(timeLabel(item.createdAt)) · \(size)"
    }

    private func timeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
        if cal.isDateInYesterday(date) { return L10n.galleryYesterday }
        let f = DateFormatter()
        f.dateFormat = "MM-dd"
        return f.string(from: date)
    }

    private func hueFromName(_ name: String) -> Double {
        var h: UInt64 = 0xcbf29ce484222325
        for b in name.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return Double(h % 100) / 100.0
    }
}
