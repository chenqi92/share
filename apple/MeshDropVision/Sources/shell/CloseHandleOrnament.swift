import SwiftUI

/// 主窗口左下 56pt 玻璃圆盘 ornament：单击关闭 / 隐藏。
struct CloseHandleOrnament: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        Button {
            // 关闭主窗口。WindowGroup(id:) 注册的稳定 id，dismissWindow 按 id 关。
            dismissWindow(id: MeshDropVisionApp.mainWindowID)
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                    .frame(width: 56, height: 56)
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MD.dpaper.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .glassBackgroundEffect(in: Circle())
    }
}
