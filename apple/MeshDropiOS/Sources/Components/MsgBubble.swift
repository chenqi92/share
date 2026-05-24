import SwiftUI

/// 聊天气泡（COMMON §7.6）。
/// - 圆角 16，非尖角方向圆角 6
/// - incoming: white (dark `rgba(255,255,255,.07)`) + ink
/// - outgoing: ink + paper (dark: lime + ink)
/// - 时间戳行 mono 10，"· 已送达" 加 limeDeep
public struct MsgBubble: View {
    public enum Kind { case text, file, image }

    let message: MockMessage
    @Environment(\.colorScheme) private var scheme

    public init(_ message: MockMessage) { self.message = message }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if message.dir == .outgoing { Spacer(minLength: 56) }
            VStack(alignment: message.dir == .outgoing ? .trailing : .leading, spacing: 4) {
                bubbleContent
                    .background(bubbleFill)
                    .foregroundStyle(textColor)
                    .clipShape(BubbleShape(side: message.dir))

                HStack(spacing: 4) {
                    Text(message.time)
                        .font(MeshDropFont.mono(10))
                        .foregroundStyle(timeColor)
                    if message.dir == .outgoing {
                        Text("· 已送达")
                            .font(MeshDropFont.mono(10))
                            .foregroundStyle(MeshDropColor.limeDeep)
                    }
                }
            }
            if message.dir == .incoming { Spacer(minLength: 56) }
        }
    }

    @ViewBuilder private var bubbleContent: some View {
        switch message.kind {
        case .text:
            Text(message.text ?? "")
                .font(MeshDropFont.body(14.5))
                .lineSpacing(2)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .fixedSize(horizontal: false, vertical: true)
        case .file:
            HStack(spacing: 10) {
                FileTile(ext: message.fileExt ?? "?", size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(message.fileName ?? "")
                        .font(MeshDropFont.body(13, weight: .semibold))
                        .lineLimit(1)
                    Text(message.fileSize ?? "")
                        .font(MeshDropFont.mono(11))
                        .opacity(0.65)
                }
            }
            .padding(10)
        case .image:
            let cols = min(3, message.imageCount ?? 1)
            HStack(spacing: 4) {
                ForEach(0..<(message.imageCount ?? 1), id: \.self) { i in
                    Photo(hue: 30 + i * 60)
                        .frame(width: 88, height: 110)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(4)
            .frame(maxWidth: CGFloat(cols) * 92 + 8)
        }
    }

    private var bubbleFill: Color {
        if message.dir == .outgoing {
            return scheme == .dark ? MeshDropColor.lime : MeshDropColor.ink
        } else {
            return scheme == .dark ? Color.white.opacity(0.07) : Color.white
        }
    }

    private var textColor: Color {
        if message.dir == .outgoing {
            return scheme == .dark ? MeshDropColor.ink : MeshDropColor.paper
        } else {
            return scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        }
    }

    private var timeColor: Color {
        scheme == .dark ? Color.white.opacity(0.4) : MeshDropColor.ink45
    }
}

private struct BubbleShape: Shape {
    let side: MockDir

    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 16
        let small: CGFloat = 6
        let tl: CGFloat = side == .incoming ? small : big
        let tr: CGFloat = side == .outgoing ? small : big
        let bl: CGFloat = big
        let br: CGFloat = big

        let path = UIBezierPath(roundedRect: rect,
                                byRoundingCorners: [.topLeft, .topRight, .bottomLeft, .bottomRight],
                                cornerRadii: CGSize(width: big, height: big))
        // 简化：用 UIBezierPath 不能直接每个角不同，需要手算路径。
        _ = path
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + tr),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - br, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - bl),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addQuadCurve(to: CGPoint(x: rect.minX + tl, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        return p
    }
}
