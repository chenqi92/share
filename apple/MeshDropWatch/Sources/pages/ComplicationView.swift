import SwiftUI

/// 表盘 complication 预览（corner / circular 两种形态）
/// 本轮 UI-FIRST 不接 ClockKit/Widget Bundle，只展示视觉。
struct ComplicationView: View {
    @ObservedObject var proxy: WatchEngineProxy = .shared

    /// Preview / 调试用：直接指定 count；nil 则走 proxy。
    var debugCount: Int? = nil

    private var count: Int {
        debugCount ?? proxy.devices.count
    }

    private var isOffline: Bool { debugCount == nil && !proxy.isOnline }

    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("COMPLICATION · 表盘")
                    .font(MDFont.mono(11, weight: .bold))
                    .tracking(1.6)
                    .foregroundColor(MD.muted)
                    .padding(.top, 4)

                // Circular 圆形 complication
                VStack(spacing: 4) {
                    Text("CIRCULAR")
                        .font(MDFont.mono(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(MD.dim)
                    ZStack {
                        Circle().fill(MD.dink2)
                            .overlay(Circle().stroke(accent, lineWidth: 2))
                            .frame(width: 64, height: 64)
                        VStack(spacing: 1) {
                            Circle().fill(accent).frame(width: 8, height: 8)
                                .shadow(color: accent.opacity(0.6), radius: 2)
                            Text(isOffline ? "—" : "\(count)")
                                .font(MDFont.display(22, weight: .bold))
                                .tracking(-0.8)
                                .foregroundColor(MD.dpaper)
                            Text(isOffline ? "OFF" : "LIVE")
                                .font(MDFont.mono(8, weight: .bold))
                                .tracking(1.4)
                                .foregroundColor(accent)
                        }
                    }
                }

                // Corner / inline complication
                VStack(spacing: 4) {
                    Text("CORNER / INLINE")
                        .font(MDFont.mono(9, weight: .bold))
                        .tracking(1.2)
                        .foregroundColor(MD.dim)
                    HStack(spacing: 4) {
                        Circle().fill(accent).frame(width: 7, height: 7)
                            .shadow(color: accent.opacity(0.6), radius: 3)
                        Text(isOffline ? "OFFLINE" : "\(count) LIVE")
                            .font(MDFont.mono(13, weight: .bold))
                            .tracking(1.6)
                            .foregroundColor(accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(MD.dink2).overlay(Capsule().stroke(accent.opacity(0.4), lineWidth: 0.5)))
                }

                Text(isOffline ? "iPhone 不在身边" : "Tap 进入 MeshDrop")
                    .font(MDFont.mono(9, weight: .medium))
                    .foregroundColor(MD.dim)
                    .padding(.top, 4)
            }
        }
    }

    private var accent: Color { isOffline ? MD.dim : MD.lime }
}

#Preview {
    ComplicationView(debugCount: 5)
}
