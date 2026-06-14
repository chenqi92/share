import SwiftUI
import MeshDropKit

struct NearbyPage: View {
    @EnvironmentObject private var engine: ShareEngine

    var body: some View {
        HStack(alignment: .top, spacing: 56) {
            // 左：巨型雷达（点位用真设备）
            MeshRadar(devices: EngineAdapters.radarDevices(from: engine.devices),
                      diameter: 640)
                .frame(width: 640, height: 640)

            // 右：配对入口 + 设备 row
            VStack(alignment: .leading, spacing: 24) {
                Text(L10n.nearbyPairIntro(engine.displayName))
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(MeshDropColor.dpaperDim)
                    .lineSpacing(4)

                MeshAsciiDivider(label: L10n.nearbyDividerScan)

                HStack(spacing: 28) {
                    MeshQRCode(content: pairURL, size: 220)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.nearbyFingerprintTag)
                            .monoTag()
                        Text(shortFingerprint)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(MeshDropColor.lime)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(L10n.nearbyThisTVTag)
                            .monoTag()
                        Text(engine.displayName)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(MeshDropColor.dpaper)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 12)

                VStack(alignment: .leading, spacing: 12) {
                    Text(headerLabel)
                        .monoTag(MeshDropColor.dpaperDim)
                    if engine.devices.isEmpty {
                        Text(L10n.nearbyEmpty)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MeshDropColor.dpaperMute)
                            .padding(.vertical, 8)
                    } else {
                        HStack(spacing: 16) {
                            ForEach(engine.devices.prefix(6), id: \.id) { d in
                                deviceChip(d)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var headerLabel: String {
        L10n.nearbyHeaderCount(engine.devices.count)
    }

    private var shortFingerprint: String {
        let fp = engine.identity.fingerprint.uppercased()
        let chunks = stride(from: 0, to: fp.count, by: 4).map { i -> String in
            let start = fp.index(fp.startIndex, offsetBy: i)
            let end = fp.index(start, offsetBy: 4, limitedBy: fp.endIndex) ?? fp.endIndex
            return String(fp[start..<end])
        }
        return chunks.prefix(2).joined(separator: " · ")
    }

    private var pairURL: String {
        "meshdrop://device/\(engine.identity.id)/\(engine.identity.fingerprint)"
    }

    private func deviceChip(_ d: Device) -> some View {
        VStack(spacing: 6) {
            Avatar(initials: d.displayInitials,
                   color: MeshDropColor.lime.opacity(0.75),
                   size: 56,
                   ring: MeshDropColor.lime)
            Text(d.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MeshDropColor.dpaper)
                .lineLimit(1)
            Text(EngineAdapters.osLabel(for: d.os))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(MeshDropColor.dpaperMute)
        }
    }
}
