import SwiftUI

/// Menubar dropdown 在主窗口里的"截图预览"。运行时真实的 dropdown 在 MenuBarDropdown.swift。
struct MenuBarPreviewPage: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            MeshDropColor.background.ignoresSafeArea()

            // 后景：模糊菜单栏 hint
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Spacer()
                    MeshDropMark(size: 18)
                    Image(systemName: "wifi").font(.system(size: 12))
                    Image(systemName: "battery.100").font(.system(size: 12))
                    Text("14:18 周一")
                        .font(MeshDropFont.mono(size: 11))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(.thinMaterial)
                Spacer()
            }
            .foregroundStyle(MeshDropColor.textSecondary)

            VStack(spacing: 8) {
                Spacer().frame(height: 36)
                MenuBarDropdown()
                    .padding(.trailing, 80)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
