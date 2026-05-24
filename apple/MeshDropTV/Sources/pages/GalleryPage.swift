import SwiftUI

struct GalleryPage: View {
    @FocusState private var focusedId: Int?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 28), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            MeshAsciiDivider(label: "TODAY · 今天 · 7 件 · NEW")
                .padding(.top, 4)

            LazyVGrid(columns: columns, spacing: 28) {
                ForEach(MockData.gallery) { item in
                    tile(item)
                        .focused($focusedId, equals: item.id)
                }
            }
            .padding(.top, 8)

            Spacer(minLength: 0)

            RemoteHint(items: [
                .init(glyph: "↕  ↔︎", label: "选择"),
                .init(glyph: "OK", label: "查看"),
                .init(glyph: "OK·长", label: "更多"),
                .init(glyph: "TV", label: "返回"),
            ])
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 36) {
            VStack(alignment: .leading, spacing: 8) {
                Text("收件箱 · LIBRARY")
                    .monoTag()
                HStack(spacing: 18) {
                    Text(MockData.gallerySummary.count)
                        .font(.system(size: 64, weight: .bold, design: .default))
                        .foregroundStyle(MeshDropColor.dpaper)
                    Text("件")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(MeshDropColor.dpaperDim)
                        .offset(y: -8)
                    Text("·")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaperMute)
                    Text(MockData.gallerySummary.size)
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                        .foregroundStyle(MeshDropColor.lime)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                Chip(text: "全部 · ALL", tone: .lime, size: 18)
                Chip(text: "图片 · PHOTOS", tone: .outline, size: 18)
                Chip(text: "文件 · FILES", tone: .outline, size: 18)
                Chip(text: "今天 · TODAY", tone: .outline, size: 18)
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: MockData.GalleryItem) -> some View {
        let focused = focusedId == item.id
        Button { } label: {
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
                    .stroke(MeshDropColor.dpaper.opacity(focused ? 0.95 : 0.0), lineWidth: 6)
            )
            .scaleEffect(focused ? 1.08 : 1.0)
            .animation(.spring(response: 0.30, dampingFraction: 0.78), value: focused)
        }
        .buttonStyle(.plain)
    }
}
