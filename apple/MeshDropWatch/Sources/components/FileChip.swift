import SwiftUI

/// 文件 mini chip：纸样 icon + 文件名 + 大小（可选进度条）
struct FileChipMini: View {
    let name: String
    let size: String
    let ext: String
    var progress: Int? = nil

    private var extColor: Color {
        switch ext.lowercased() {
        case "pdf": return MD.flame
        case "fig": return Color(red: 0.78, green: 0.50, blue: 1.00)
        case "zip", "7z", "tar": return MD.sky
        case "mp4", "mov": return MD.flame
        case "pages", "doc", "docx", "md": return MD.lime
        case "heic", "png", "jpg": return MD.sky
        default: return MD.muted
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // 纸样 icon
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(MD.dpaper)
                    .frame(width: 26, height: 32)
                // 右上折角
                Path { p in
                    p.move(to: CGPoint(x: 18, y: 0))
                    p.addLine(to: CGPoint(x: 26, y: 8))
                    p.addLine(to: CGPoint(x: 18, y: 8))
                    p.closeSubpath()
                }
                .fill(MD.dpaper.opacity(0.55))
                .frame(width: 26, height: 32, alignment: .topTrailing)
                // 扩展名
                Text(ext.uppercased())
                    .font(MDFont.mono(7, weight: .bold))
                    .foregroundColor(extColor)
                    .frame(width: 26, height: 32, alignment: .bottom)
                    .padding(.bottom, 4)
            }
            .frame(width: 26, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(MDFont.body(12, weight: .medium))
                    .foregroundColor(MD.dpaper)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(size)
                    .font(MDFont.mono(10, weight: .regular))
                    .foregroundColor(MD.muted)
                if let p = progress {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(MD.dline).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2).fill(MD.sky).frame(width: g.size.width * CGFloat(p) / 100.0, height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MD.dink2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(MD.dline, lineWidth: 0.5)
                )
        )
    }
}

/// 大写 mono tag chip
struct MonoTag: View {
    let text: String
    var tone: Tone = .mute
    enum Tone { case mute, lime, ink, flame, sky, error }

    private var fg: Color {
        switch tone {
        case .mute: return MD.muted
        case .lime: return MD.dink
        case .ink:  return MD.dpaper
        case .flame: return .white
        case .sky:  return .white
        case .error: return .white
        }
    }
    private var bg: Color {
        switch tone {
        case .mute: return MD.dline
        case .lime: return MD.lime
        case .ink:  return MD.dink3
        case .flame: return MD.flame
        case .sky:  return MD.sky
        case .error: return MD.error
        }
    }

    var body: some View {
        Text(text.uppercased())
            .font(MDFont.mono(10, weight: .bold))
            .tracking(1.6)
            .foregroundColor(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(bg))
    }
}
