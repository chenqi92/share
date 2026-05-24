import SwiftUI

/// 左右两条 hr + 中间 mono 全大写 label（letterSpacing 1.5+, opacity 0.45）。
/// 例：── TODAY · 今天 · 5 件 ──
public struct AsciiDivider: View {
    let label: String
    @Environment(\.colorScheme) private var scheme

    public init(_ label: String) { self.label = label }

    public var body: some View {
        HStack(spacing: 10) {
            line
            Text(label.uppercased())
                .font(MeshDropFont.mono(10, weight: .bold))
                .tracking(1.5)
                .foregroundStyle((scheme == .dark ? Color.white : .black).opacity(0.45))
                .layoutPriority(1)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill((scheme == .dark ? Color.white : .black).opacity(0.18))
            .frame(height: 1)
    }
}
