import SwiftUI

/// 表盘 complication 预览（corner / circular 两种形态）
/// 本轮 UI-FIRST 不接 ClockKit/Widget Bundle，只展示视觉。
struct ComplicationView: View {
    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("COMPLICATION · 表盘")
                    .font(MDFont.mono(11, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(MD.muted)
                    .padding(.top, 4)

                // Circular 圆形 complication（mock 渲染：● 5 LIVE）
                VStack(spacing: 4) {
                    Text("CIRCULAR")
                        .font(MDFont.mono(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(MD.dim)
                    ZStack {
                        Circle().fill(MD.dink2)
                            .overlay(Circle().stroke(MD.lime, lineWidth: 2))
                            .frame(width: 64, height: 64)
                        VStack(spacing: 1) {
                            Circle().fill(MD.lime).frame(width: 8, height: 8)
                                .shadow(color: MD.lime.opacity(0.6), radius: 2)
                            Text("5")
                                .font(MDFont.display(22, weight: .bold))
                                .tracking(-0.8)
                                .foregroundColor(MD.dpaper)
                            Text("LIVE")
                                .font(MDFont.mono(8, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(MD.lime)
                        }
                    }
                }

                // Corner / inline complication: "● 5 LIVE"
                VStack(spacing: 4) {
                    Text("CORNER / INLINE")
                        .font(MDFont.mono(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(MD.dim)
                    HStack(spacing: 4) {
                        Circle().fill(MD.lime).frame(width: 7, height: 7)
                            .shadow(color: MD.lime.opacity(0.6), radius: 3)
                        Text("5 LIVE")
                            .font(MDFont.mono(13, weight: .bold))
                            .tracking(1.6)
                            .foregroundColor(MD.lime)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(MD.dink2).overlay(Capsule().stroke(MD.lime.opacity(0.4), lineWidth: 0.5)))
                }

                Text("Tap 进入 MeshDrop")
                    .font(MDFont.mono(9, weight: .medium))
                    .foregroundColor(MD.dim)
                    .padding(.top, 4)
            }
        }
    }
}

#Preview {
    ComplicationView()
}
