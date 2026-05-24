import SwiftUI

/// ASCII 风格分隔线：── LABEL ──
struct MeshAsciiDivider: View {
    var label: String
    var color: Color = MeshDropColor.dpaperMute

    var body: some View {
        HStack(spacing: 18) {
            line
            Text(label)
                .font(MeshDropFont.monoTag())
                .tracking(2.4)
                .textCase(.uppercase)
                .foregroundStyle(color)
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(color.opacity(0.5))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}
