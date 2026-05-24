import SwiftUI

/// sidebar / 列表行用的小卡片。
/// avatar(32) + KindGlyph + 设备名(13.5/600) + 副标题（OS · RTT）+ 右下角小绿点。
struct DeviceCard: View {
    let device: MockDevice
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Avatar(initials: device.initials, color: device.color, size: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(MeshDropFont.body(size: 13.5, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    KindGlyph(kind: device.kind, size: 10)
                    Text("\(device.os) · \(device.rtt)ms")
                        .font(MeshDropFont.mono(size: 10))
                        .foregroundStyle(MeshDropColor.textMuted)
                }
            }
            Spacer(minLength: 0)
            if device.online {
                Circle()
                    .fill(MeshDropColor.limeDeep)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(selected ? MeshDropColor.limeFillSelected : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? MeshDropColor.lime : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }
}
