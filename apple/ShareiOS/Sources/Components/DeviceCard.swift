import SwiftUI

/// 侧栏 / 列表行用的小卡片：avatar(32) + KindGlyph + 设备名(13.5/600) +
/// 副标题（OS · RTT）+ 右下角小绿点（在线）。
public struct DeviceCard: View {
    let device: MockDevice
    var selected: Bool = false
    var dense: Bool = false

    @Environment(\.colorScheme) private var scheme

    public init(_ device: MockDevice, selected: Bool = false, dense: Bool = false) {
        self.device = device
        self.selected = selected
        self.dense = dense
    }

    public var body: some View {
        HStack(spacing: 12) {
            Avatar(initials: device.initials, color: device.color,
                   size: dense ? 28 : 32, online: device.isOnline)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    KindGlyph(device.kind, size: 11)
                    Text(device.name)
                        .font(MeshDropFont.body(13.5, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(device.os)
                        .font(MeshDropFont.mono(10.5))
                    Text("·").foregroundStyle(textMuted.opacity(0.5))
                    HStack(spacing: 2) {
                        Text("\(device.rtt)")
                            .monospacedDigit()
                        Text("ms")
                            .font(MeshDropFont.mono(8.5))
                            .baselineOffset(0.5)
                    }
                    .font(MeshDropFont.mono(10.5))
                }
                .foregroundStyle(textMuted)
            }
            Spacer(minLength: 4)

            if device.isOnline {
                Circle().fill(MeshDropColor.limeDeep)
                    .frame(width: 6, height: 6)
            } else {
                Circle().stroke(textMuted, lineWidth: 1)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, dense ? 8 : 10)
        .background(background)
        .overlay(borderOverlay)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var textPrimary: Color { scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink }
    private var textMuted:   Color { scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45 }

    @ViewBuilder private var background: some View {
        if selected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.lime.opacity(0.16) : MeshDropColor.lime.opacity(0.32))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        }
    }

    @ViewBuilder private var borderOverlay: some View {
        if selected {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(MeshDropColor.lime, lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        }
    }
}
