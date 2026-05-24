import SwiftUI

/// "纸样" icon：白底 + 右上折角阴影 + 中下方 mono 大写扩展名。
public struct FileTile: View {
    let ext: String
    var size: CGFloat = 38

    @Environment(\.colorScheme) private var scheme

    public init(ext: String, size: CGFloat = 38) {
        self.ext = ext.uppercased()
        self.size = size
    }

    public var body: some View {
        let w = size, h = size * 1.21
        ZStack {
            // 折角 shadow 底
            FilePaperShape(corner: w * 0.28)
                .fill(scheme == .dark ? MeshDropColor.dpaper.opacity(0.95) : Color.white)
                .overlay(
                    FilePaperShape(corner: w * 0.28)
                        .stroke(scheme == .dark ? Color.black.opacity(0.4) : MeshDropColor.ink12, lineWidth: 0.7)
                )
                .overlay(
                    // 折角小三角填充
                    FoldedCornerShape(corner: w * 0.28)
                        .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.ink06)
                )
                .frame(width: w, height: h)

            VStack {
                Spacer()
                Text(ext)
                    .font(MeshDropFont.mono(w * 0.22, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(extColor(for: ext))
                    .padding(.bottom, h * 0.16)
            }
            .frame(width: w, height: h)
        }
        .frame(width: w, height: h)
    }

    private func extColor(for e: String) -> Color {
        switch e {
        case "FIG", "SKETCH":             return Color(red: 0.95, green: 0.42, blue: 0.18)
        case "ZIP", "TAR", "GZ", "7Z":    return Color(red: 0.6, green: 0.4, blue: 0.0)
        case "PDF":                        return Color(red: 0.78, green: 0.20, blue: 0.17)
        case "MP4", "MOV", "AVI":          return Color(red: 0.30, green: 0.55, blue: 0.90)
        case "HEIC", "JPG", "PNG", "WEBP": return Color(red: 0.20, green: 0.55, blue: 0.35)
        case "MD", "TXT":                  return MeshDropColor.ink60
        case "PAGES", "DOCX":              return Color(red: 0.20, green: 0.40, blue: 0.85)
        default:                            return MeshDropColor.ink60
        }
    }
}

/// 文件 chip：左侧纸样 + 右侧文件名 + 大小 + 可选 progress。
public struct FileChip: View {
    let name: String
    let size: String
    let ext: String
    let progress: Double?       // 0...1 or nil

    @Environment(\.colorScheme) private var scheme

    public init(name: String, size: String, ext: String, progress: Double? = nil) {
        self.name = name; self.size = size; self.ext = ext; self.progress = progress
    }

    public var body: some View {
        HStack(spacing: 10) {
            FileTile(ext: ext, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(MeshDropFont.body(13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(size)
                        .font(MeshDropFont.mono(11))
                        .foregroundStyle(muted)
                    if let p = progress {
                        Text("· \(Int(p * 100))%")
                            .font(MeshDropFont.mono(11, weight: .medium))
                            .foregroundStyle(MeshDropColor.flame)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark ? Color.white.opacity(0.04) : MeshDropColor.ink06)
        )
        .overlay(alignment: .bottom) {
            if let p = progress {
                GeometryReader { geo in
                    Rectangle()
                        .fill(MeshDropColor.flame)
                        .frame(width: geo.size.width * p, height: 2)
                        .padding(.leading, 0)
                }
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 0)
                .padding(.bottom, 0)
            }
        }
    }

    private var muted: Color {
        scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45
    }
}

// MARK: - Shapes

private struct FilePaperShape: Shape {
    let corner: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 4
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        return p
    }
}

private struct FoldedCornerShape: Shape {
    let corner: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY + corner))
        p.closeSubpath()
        return p
    }
}
