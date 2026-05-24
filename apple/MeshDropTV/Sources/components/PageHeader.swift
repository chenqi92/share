import SwiftUI

/// 所有 page 顶部统一 header：固定高度 110pt，monoTag (14pt) + 大字 (44pt) 起点 y 完全一致。
/// 右侧 trailing 区给 chips / 状态 / actions 使用。
struct PageHeader<Trailing: View>: View {
    var tag: String
    var title: String
    var titleAccentSuffix: String?
    var titleAccentColor: Color = MeshDropColor.lime
    @ViewBuilder var trailing: () -> Trailing

    init(tag: String,
         title: String,
         titleAccentSuffix: String? = nil,
         titleAccentColor: Color = MeshDropColor.lime,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.tag = tag
        self.title = title
        self.titleAccentSuffix = titleAccentSuffix
        self.titleAccentColor = titleAccentColor
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tag)
                    .monoTag()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(title)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    if let suffix = titleAccentSuffix {
                        Text(suffix)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(titleAccentColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            Spacer(minLength: 16)
            trailing()
                .fixedSize(horizontal: true, vertical: false)
        }
        .frame(height: 110, alignment: .bottom)
    }
}
