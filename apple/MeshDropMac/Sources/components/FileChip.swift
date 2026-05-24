import SwiftUI

/// 左侧"纸样"icon + 右侧文件名 + 大小。可选 progress 显示底部进度条。
struct FileChip: View {
    let name: String
    let size: String
    let ext: String
    var progress: Double? = nil
    var dark: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                FileIcon(ext: ext)
                    .frame(width: 38, height: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(MeshDropFont.body(size: 13, weight: .semibold))
                        .foregroundStyle(dark ? MeshDropColor.dpaper : MeshDropColor.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(size)
                        .font(MeshDropFont.mono(size: 11))
                        .foregroundStyle(dark ? Color.white.opacity(0.55) : MeshDropColor.textMuted)
                }
                Spacer(minLength: 0)
            }
            if let progress {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MeshDropColor.divider)
                        .frame(height: 4)
                    Capsule()
                        .fill(MeshDropColor.flame)
                        .frame(width: max(2, CGFloat(progress) * 240), height: 4)
                }
            }
        }
    }
}

/// 文件 icon：白底 + 右上折角阴影 + 中下方 mono 大写扩展名。
struct FileIcon: View {
    let ext: String
    var color: Color = MeshDropColor.flame

    var body: some View {
        ZStack(alignment: .bottom) {
            FileIconShape()
                .fill(.white)
                .overlay(
                    FileIconShape()
                        .stroke(MeshDropColor.ink12, lineWidth: 1)
                )
                .shadow(color: MeshDropColor.ink12, radius: 2, x: 0, y: 1)
            Text(ext.uppercased())
                .font(MeshDropFont.mono(size: 9, weight: .bold))
                .foregroundStyle(color)
                .padding(.bottom, 4)
        }
    }
}

struct FileIconShape: Shape {
    func path(in rect: CGRect) -> Path {
        let fold: CGFloat = min(10, rect.width * 0.28)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 2, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - 2),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 2))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 2, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        // 折角小阴影
        p.move(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY + fold))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        return p
    }
}
