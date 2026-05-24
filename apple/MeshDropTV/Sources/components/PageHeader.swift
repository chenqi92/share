import SwiftUI

/// 所有 page 顶部统一 header：固定高度 96pt。
///
/// 内部结构（两行 visual rhythm，所有 page 完全一致）：
/// - 第一行 (y=0)：左侧 monoTag (14pt uppercase) + 右侧 trailing chips
/// - 第二行 (y≈22)：48pt 大字标题（可选 lime accent suffix）
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
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：tag 左 + trailing 右，高度严格匹配 14pt monoTag
            HStack(alignment: .center, spacing: 16) {
                Text(tag)
                    .monoTag()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 16)
                trailing()
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(height: 22)

            // 第二行：大字标题
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
            .frame(height: 56, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 96, alignment: .top)
    }
}
