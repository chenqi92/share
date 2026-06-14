import SwiftUI
import MeshDropKit

private enum ReceiveFocus: Hashable {
    case ctaPrimary
    case ctaReject
}

struct ReceivePage: View {
    @EnvironmentObject private var engine: ShareEngine
    @FocusState private var focused: ReceiveFocus?

    var body: some View {
        if let offer = engine.pendingFileOffers.first {
            activeOffer(offer)
        } else {
            emptyState
        }
    }

    // MARK: - 等候态

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 36) {
                VStack(alignment: .leading, spacing: 18) {
                    placeholderHero
                    Spacer(minLength: 0)
                    RemoteHint(items: [
                        .init(glyph: "TV", label: "返回主屏"),
                    ])
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(0)

                waitingPanel
                    .frame(width: 460, alignment: .top)
                    .layoutPriority(1)
            }
        }
    }

    private var placeholderHero: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(MeshDropColor.dink2)
            .overlay(
                VStack(spacing: 14) {
                    Text("WAITING")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundStyle(MeshDropColor.dpaperMute)
                    Text("等手机推过来…")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(MeshDropColor.dpaperDim)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(MeshDropColor.dline, lineWidth: 1)
            )
            .aspectRatio(3.0 / 2.0, contentMode: .fit)
    }

    private var waitingPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("空闲 · IDLE")
                .monoTag()
            Text("没有正在传入的内容。\n在你手机上打开 MeshDrop，把照片或文件推到「\(engine.displayName)」。")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MeshDropColor.dpaper)
                .lineSpacing(6)

            MeshAsciiDivider(label: "附近 · NEARBY · \(engine.devices.count) 台")

            VStack(alignment: .leading, spacing: 12) {
                if engine.devices.isEmpty {
                    Text("附近还没有 MeshDrop 设备。")
                        .font(.system(size: 18))
                        .foregroundStyle(MeshDropColor.dpaperMute)
                } else {
                    ForEach(engine.devices.prefix(5), id: \.id) { d in
                        peerRow(d)
                    }
                }
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MeshDropColor.dink2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MeshDropColor.dline, lineWidth: 1)
        )
    }

    private func peerRow(_ d: Device) -> some View {
        HStack(spacing: 14) {
            Avatar(initials: d.displayInitials,
                   color: MeshDropColor.lime.opacity(0.65),
                   size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MeshDropColor.dpaper)
                    .lineLimit(1)
                Text("\(EngineAdapters.osLabel(for: d.os)) · \(d.id.prefix(8))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaperMute)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    // MARK: - 有 offer

    @ViewBuilder
    private func activeOffer(_ offer: PendingFileOffer) -> some View {
        HStack(alignment: .top, spacing: 36) {
            VStack(alignment: .leading, spacing: 18) {
                offerHero(offer)
                Spacer(minLength: 0)
                RemoteHint(items: [
                    .init(glyph: "OK",  label: "接收并保存"),
                    .init(glyph: "▶︎", label: "拒绝"),
                    .init(glyph: "TV",  label: "返回"),
                ])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            sidePanel(offer)
                .frame(width: 460, alignment: .top)
                .layoutPriority(1)
        }
        .onAppear { focused = .ctaPrimary }
    }

    private func offerHero(_ offer: PendingFileOffer) -> some View {
        let hue = hueFromName(offer.fileName)
        return ZStack(alignment: .topLeading) {
            PhotoPlaceholder(hue: hue, aspect: 3.0 / 2.0, corner: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MeshDropColor.dline, lineWidth: 1)
                )

            HStack(spacing: 10) {
                Text("INCOMING")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .tracking(2)
                Text("·").foregroundStyle(MeshDropColor.dpaperMute)
                Text(offer.formattedSize)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(MeshDropColor.dpaper)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(MeshDropColor.ink.opacity(0.75)))
            .padding(20)
        }
    }

    private func sidePanel(_ offer: PendingFileOffer) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("来自 · FROM")
                .monoTag()

            HStack(spacing: 18) {
                Avatar(initials: offer.peer.displayInitials,
                       color: MeshDropColor.lime.opacity(0.85),
                       size: 84,
                       ring: MeshDropColor.lime)
                VStack(alignment: .leading, spacing: 4) {
                    Text(offer.peer.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                    Text("\(EngineAdapters.osLabel(for: offer.peer.os)) · \(offer.peer.humanFingerprint.prefix(14))…")
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MeshDropColor.dpaperMute)
                        .lineLimit(1)
                }
            }

            fileCard(offer)

            VStack(alignment: .leading, spacing: 12) {
                ctaButton(.ctaPrimary,
                          title: "接收并保存",
                          subtitle: "OK · ACCEPT",
                          tone: .lime,
                          fillWidth: true) {
                    engine.respondToFileOffer(offer.id, accept: true)
                }
                ctaButton(.ctaReject,
                          title: "不接收",
                          subtitle: "REJECT",
                          tone: .mute,
                          fillWidth: true) {
                    engine.respondToFileOffer(offer.id, accept: false)
                }
            }
            .padding(.top, 4)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(MeshDropColor.dink2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MeshDropColor.dline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func ctaButton(_ id: ReceiveFocus,
                           title: String,
                           subtitle: String?,
                           tone: ChipTone,
                           fillWidth: Bool,
                           action: @escaping () -> Void) -> some View {
        let isFocusedCTA = focused == id
        InvisibleFocusButton(isFocused: $focused, value: id, action: action) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(ctaFG(tone))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .tracking(1.3)
                            .textCase(.uppercase)
                            .foregroundStyle(ctaFG(tone).opacity(0.65))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                if fillWidth { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ctaBG(tone))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .inset(by: 2)
                    .strokeBorder(ctaRing(tone).opacity(isFocusedCTA ? 0.95 : 0.0), lineWidth: 3)
            )
            .animation(.easeInOut(duration: 0.18), value: isFocusedCTA)
        }
    }

    private func ctaBG(_ tone: ChipTone) -> Color {
        switch tone {
        case .lime: return MeshDropColor.lime
        case .ink:  return MeshDropColor.dink3
        case .mute: return MeshDropColor.dink2
        default:    return MeshDropColor.dink3
        }
    }
    private func ctaFG(_ tone: ChipTone) -> Color {
        switch tone {
        case .lime: return MeshDropColor.ink
        case .mute: return MeshDropColor.dpaperDim
        default:    return MeshDropColor.dpaper
        }
    }
    private func ctaRing(_ tone: ChipTone) -> Color {
        switch tone {
        case .lime: return MeshDropColor.ink
        default:    return MeshDropColor.dpaper
        }
    }

    private func fileCard(_ offer: PendingFileOffer) -> some View {
        HStack(spacing: 16) {
            FileTile(ext: ext(of: offer.fileName), hue: hueFromName(offer.fileName))
                .frame(width: 76, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(offer.fileName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MeshDropColor.dpaper)
                    .lineLimit(1)
                Text(offer.formattedSize)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaperMute)
                HStack(spacing: 8) {
                    Chip(text: "● LAN", tone: .lime, mono: true, size: 13)
                    Chip(text: "明文 · v0.1", tone: .outline, mono: true, size: 13)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MeshDropColor.dink3)
        )
    }

    private func ext(of name: String) -> String {
        let last = (name as NSString).pathExtension
        return last.isEmpty ? "FILE" : last.uppercased()
    }

    private func hueFromName(_ name: String) -> Double {
        var h: UInt64 = 0xcbf29ce484222325
        for b in name.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return Double(h % 100) / 100.0
    }
}
