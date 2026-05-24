import SwiftUI

/// 圆形 / 方形小按钮。size 32 默认。accent=true 时 lime 底 + ink 字。
struct IconBtn: View {
    let systemName: String
    var size: CGFloat = 32
    var accent: Bool = false
    var rounded: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(accent ? MeshDropColor.ink : MeshDropColor.textPrimary)
                .frame(width: size, height: size)
                .background(
                    Group {
                        if rounded {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(accent ? MeshDropColor.lime : MeshDropColor.cardBg2)
                        } else {
                            Circle()
                                .fill(accent ? MeshDropColor.lime : MeshDropColor.cardBg2)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
    }
}
