import SwiftUI

/// 两个重叠圆环 + lime 实心圆点（暗底版本：stroke 用 dpaper）
struct MeshDropMark: View {
    let size: CGFloat
    init(size: CGFloat = 14) { self.size = size }
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width
            let h = sz.height
            let ringR = w * (6.5/24.0)
            let leftC = CGPoint(x: w * (9.0/24.0),  y: h * 0.5)
            let rightC = CGPoint(x: w * (15.0/24.0), y: h * 0.5)
            var leftRing = Path()
            leftRing.addEllipse(in: CGRect(x: leftC.x - ringR, y: leftC.y - ringR, width: ringR*2, height: ringR*2))
            var rightRing = Path()
            rightRing.addEllipse(in: CGRect(x: rightC.x - ringR, y: rightC.y - ringR, width: ringR*2, height: ringR*2))
            ctx.stroke(leftRing,  with: .color(MD.dpaper), lineWidth: w * (2.0/24.0))
            ctx.stroke(rightRing, with: .color(MD.dpaper), lineWidth: w * (2.0/24.0))

            let dotR = w * (1.8/24.0)
            let dot = Path(ellipseIn: CGRect(x: w*0.5 - dotR, y: h*0.5 - dotR, width: dotR*2, height: dotR*2))
            ctx.fill(dot, with: .color(MD.lime))
        }
        .frame(width: size, height: size)
    }
}

struct MeshDropWordmark: View {
    let size: CGFloat
    init(size: CGFloat = 12) { self.size = size }
    var body: some View {
        HStack(spacing: 2) {
            Text("meshdrop")
                .font(MDFont.display(size, weight: .semibold))
                .foregroundColor(MD.dpaper)
                .tracking(-0.4)
            Circle().fill(MD.lime).frame(width: size * 0.28, height: size * 0.28)
                .offset(y: size * 0.35)
        }
    }
}

struct MeshDropLockup: View {
    var body: some View {
        HStack(spacing: 4) {
            MeshDropMark(size: 14)
            MeshDropWordmark(size: 11)
        }
    }
}
