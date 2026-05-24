import SwiftUI

/// 中央磨砂玻璃面板（960×640）：hero copy + 已选 payload + 操作提示。
struct MainWindow: View {
    var body: some View {
        GlassCard(corner: 38) {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                    .overlay(MD.dline)
                    .padding(.vertical, 18)
                heroCopy
                Spacer().frame(height: 26)
                selectedPayloadBlock
                Spacer()
                gazePinchHint
            }
            .padding(.horizontal, 36)
            .padding(.top, 28)
            .padding(.bottom, 28)
            .frame(width: 580, height: 540, alignment: .topLeading)
        }
    }

    // MARK: head
    private var header: some View {
        HStack(spacing: 14) {
            MeshDropLockup(size: 26)
            Chip(text: "SPATIAL · 客厅", tone: .outline, mono: true)
            Spacer()
            Chip(text: "● 5 PEERS", tone: .lime, mono: true)
        }
    }

    // MARK: hero copy
    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("你身边的设备")
                .font(MDFont.hero)
                .foregroundStyle(MD.dpaper)
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("都已就位.")
                    .font(MDFont.hero)
                    .foregroundStyle(MD.lime)
                Image(systemName: "arrow.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MD.dpaper.opacity(0.45))
            }
            Text("看向任意一台设备 · 捏合即发送")
                .font(MDFont.body)
                .foregroundStyle(MD.dpaper.opacity(0.65))
                .padding(.top, 4)
        }
    }

    // MARK: 已选 payload
    private var selectedPayloadBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            ASCIIDivider(label: "Selected · 已选 · \(MockData.selectedPayload.count) 项 · \(MockData.selectedPayload.totalSize)")

            HStack(spacing: 12) {
                ForEach(Array(MockData.selectedPayload.imageHues.enumerated()), id: \.offset) { _, hue in
                    Photo(hue: hue, corner: 12)
                        .frame(width: 96, height: 124)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 18, x: 0, y: 12)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("12.4 MB")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(MD.dpaper)
                    Text("3 张 · jpeg / heic")
                        .font(MDFont.micro)
                        .foregroundStyle(MD.dpaper.opacity(0.55))
                }
            }
        }
    }

    // MARK: gaze · pinch · 长按 提示行
    private var gazePinchHint: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .semibold))
                Text("GAZE")
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MD.dpaper.opacity(0.35))
            HStack(spacing: 8) {
                Image(systemName: "hand.pinch")
                    .font(.system(size: 11, weight: .semibold))
                Text("PINCH")
            }
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MD.dpaper.opacity(0.35))
            HStack(spacing: 8) {
                Image(systemName: "hand.point.up.left.and.text")
                    .font(.system(size: 11, weight: .semibold))
                Text("HOLD · 上下文")
            }
            Spacer()
            Text("E2E · LAN ONLY")
                .font(MDFont.microHi).tracking(1.6).textCase(.uppercase)
                .foregroundStyle(MD.limeDeep)
        }
        .font(MDFont.chipMono)
        .tracking(1.6)
        .textCase(.uppercase)
        .foregroundStyle(MD.dpaper.opacity(0.65))
    }
}
