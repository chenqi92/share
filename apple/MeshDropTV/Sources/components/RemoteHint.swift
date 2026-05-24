import SwiftUI

/// 底部遥控器按键提示条。tvOS 3 米外要明显。
struct RemoteHint: View {
    struct Item: Identifiable {
        let id = UUID()
        let glyph: String   // 用 mono uppercase 表达，例 "OK" "▶︎" "TV"
        let label: String   // "接收" 等
    }
    var items: [Item]

    var body: some View {
        HStack(spacing: 28) {
            ForEach(items) { item in
                HStack(spacing: 10) {
                    Text(item.glyph)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(MeshDropColor.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(MeshDropColor.dpaper)
                        )
                    Text(item.label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MeshDropColor.dpaperDim)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Capsule(style: .continuous)
                .fill(MeshDropColor.dink2.opacity(0.85))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(MeshDropColor.dline, lineWidth: 1)
        )
    }
}

/// 文件类型小 Tile —— gallery 用
struct FileTile: View {
    var ext: String
    var hue: Double = 0.5

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hue: hue, saturation: 0.30, brightness: 0.30))
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
            VStack {
                Spacer()
                Text(ext)
                    .font(.system(size: 26, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color(hue: hue, saturation: 0.55, brightness: 0.92))
                Spacer().frame(height: 24)
            }
        }
    }
}
