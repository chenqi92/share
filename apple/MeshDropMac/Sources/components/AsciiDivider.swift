import SwiftUI

/// 左右两条 hr + 中间 mono 全大写 label。营造极客感。
/// 例：`── TODAY · 今天 · 5 件 ──`
struct AsciiDivider: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(MeshDropColor.divider)
                .frame(height: 1)
            Text(text)
                .font(MeshDropFont.divider(10))
                .textCase(.uppercase)
                .tracking(1.8)
                .foregroundStyle(MeshDropColor.textMuted)
            Rectangle()
                .fill(MeshDropColor.divider)
                .frame(height: 1)
        }
        .padding(.vertical, 6)
    }
}
