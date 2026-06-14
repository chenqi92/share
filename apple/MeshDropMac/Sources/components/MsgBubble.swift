import SwiftUI

enum BubbleSide { case incoming, outgoing }
enum BubbleKind { case text, file, image }

/// side=in/out，圆角 16，**非尖角方向圆角 6**。
/// outgoing light = ink 黑底 paper 字 / outgoing dark = **lime** 底 ink 字。
struct MsgBubble<Content: View>: View {
    let side: BubbleSide
    var kind: BubbleKind = .text
    var time: String = ""
    var delivered: Bool = false
    @ViewBuilder var content: Content

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let radius: CGFloat = 16
        let inset: CGFloat = 6
        VStack(alignment: side == .outgoing ? .trailing : .leading, spacing: 4) {
            content
                .padding(padding)
                .background(bg)
                .foregroundStyle(fg)
                .clipShape(BubbleShape(side: side, radius: radius, inset: inset))

            if !time.isEmpty {
                HStack(spacing: 4) {
                    if side == .outgoing { Spacer() }
                    Text(time)
                        .font(MeshDropFont.mono(size: 10))
                        .foregroundStyle(MeshDropColor.textMuted)
                    if delivered && side == .outgoing {
                        Text("msg.delivered")
                            .font(MeshDropFont.mono(size: 10))
                            .foregroundStyle(MeshDropColor.limeDeep)
                    }
                    if side == .incoming { Spacer() }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: side == .outgoing ? .trailing : .leading)
    }

    private var padding: EdgeInsets {
        switch kind {
        case .text:  return EdgeInsets(top: 8,  leading: 12, bottom: 8,  trailing: 12)
        case .file:  return EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        case .image: return EdgeInsets(top: 4,  leading: 4,  bottom: 4,  trailing: 4)
        }
    }

    private var bg: Color {
        switch side {
        case .outgoing: return MeshDropColor.outgoingBubble
        case .incoming: return MeshDropColor.incomingBubble
        }
    }

    private var fg: Color {
        switch side {
        case .outgoing: return MeshDropColor.outgoingText
        case .incoming: return MeshDropColor.textPrimary
        }
    }
}

/// 自定义气泡形状：非尖角方向圆角 16，尖角方向圆角 6。
struct BubbleShape: Shape {
    let side: BubbleSide
    var radius: CGFloat = 16
    var inset: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let r = radius
        let i = inset
        // tl, tr, br, bl
        let tl: CGFloat = (side == .incoming) ? i : r
        let tr: CGFloat = (side == .outgoing) ? i : r
        let br: CGFloat = r
        let bl: CGFloat = r

        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                 radius: tr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        p.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                 radius: br, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                 radius: bl, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        p.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                 radius: tl, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}
