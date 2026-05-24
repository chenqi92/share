import SwiftUI

private enum ReceiveFocus: Hashable {
    case thumb(Int)
    case ctaPrimary
    case ctaSave
    case ctaReject
}

struct ReceivePage: View {
    @State private var selected: Int = MockData.incomingFromIndex
    @FocusState private var focused: ReceiveFocus?

    private let lastThumbId = MockData.incomingPhotos.last?.id ?? 0
    private let firstThumbId = MockData.incomingPhotos.first?.id ?? 0

    var body: some View {
        HStack(alignment: .top, spacing: 36) {
            VStack(alignment: .leading, spacing: 18) {
                heroPhoto
                thumbnailStrip
                Spacer(minLength: 0)
                remoteHint
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(0)

            sidePanel
                .frame(width: 460, alignment: .top)
                .layoutPriority(1)
        }
    }

    private var heroPhoto: some View {
        ZStack(alignment: .topLeading) {
            let item = MockData.incomingPhotos[max(0, min(selected, MockData.incomingPhotos.count - 1))]
            PhotoPlaceholder(hue: item.hue, aspect: 3.0 / 2.0, corner: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(MeshDropColor.dline, lineWidth: 1)
                )

            HStack(spacing: 10) {
                Text("\(item.label)").font(.system(size: 18, weight: .bold, design: .monospaced))
                Text("·").foregroundStyle(MeshDropColor.dpaperMute)
                Text(MockData.incomingFileExt).font(.system(size: 18, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(MeshDropColor.dpaper)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Capsule().fill(MeshDropColor.ink.opacity(0.75)))
            .padding(20)
        }
    }

    private var thumbnailStrip: some View {
        HStack(spacing: 18) {
            ForEach(MockData.incomingPhotos) { item in
                thumbButton(item)
            }
            placeholderTile
        }
    }

    @ViewBuilder
    private func thumbButton(_ item: MockData.IncomingPhoto) -> some View {
        let isFocusedThumb = focused == .thumb(item.id)
        InvisibleFocusButton(isFocused: $focused, value: ReceiveFocus.thumb(item.id)) {
            selected = item.id - 1
        } content: {
            PhotoPlaceholder(hue: item.hue, aspect: 1, corner: 12)
                .frame(width: 124, height: 124)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .inset(by: 1.5)
                        .strokeBorder(selected == item.id - 1 ? MeshDropColor.lime : Color.clear, lineWidth: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .inset(by: 2)
                        .strokeBorder(MeshDropColor.dpaper.opacity(isFocusedThumb ? 0.95 : 0.0), lineWidth: 2.5)
                )
                .animation(.easeInOut(duration: 0.18), value: isFocusedThumb)
        }
        // 最后一个 thumb 上按 →，主动把焦点推到 sidePanel 主 CTA，跨过 HStack 边界
        .onMoveCommand { direction in
            if item.id == lastThumbId, direction == .right {
                focused = .ctaPrimary
            }
        }
    }

    private var placeholderTile: some View {
        VStack(spacing: 4) {
            Text("+10")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(MeshDropColor.dpaperDim)
            Text("张")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(MeshDropColor.dpaperMute)
        }
        .frame(width: 124, height: 124)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MeshDropColor.dink3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MeshDropColor.dline, lineWidth: 1)
        )
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("来自 · FROM")
                .monoTag()

            HStack(spacing: 18) {
                Avatar(initials: MockData.incomingPeer.initials, color: MockData.incomingPeer.color, size: 84, ring: MeshDropColor.lime)
                VStack(alignment: .leading, spacing: 4) {
                    Text(MockData.incomingPeer.who)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                    Text(MockData.incomingPeer.name)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MeshDropColor.dpaperMute)
                }
            }

            fileCard

            VStack(alignment: .leading, spacing: 12) {
                ctaButton(.ctaPrimary,
                          title: "接收并播放",
                          subtitle: "OK · 同时进入幻灯片",
                          tone: .lime,
                          fillWidth: true)
                HStack(spacing: 14) {
                    ctaButton(.ctaSave,
                              title: "仅保存",
                              subtitle: "SAVE",
                              tone: .ink,
                              fillWidth: true)
                    ctaButton(.ctaReject,
                              title: "不接收",
                              subtitle: "REJECT",
                              tone: .mute,
                              fillWidth: true)
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
                           fillWidth: Bool) -> some View {
        let isFocusedCTA = focused == id
        InvisibleFocusButton(isFocused: $focused, value: id) {
            // mock：本轮不接 backend
        } content: {
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
        // 主 CTA 上按 ←，把焦点推回最后一个缩略图
        .onMoveCommand { direction in
            if id == .ctaPrimary, direction == .left {
                focused = .thumb(lastThumbId)
            }
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

    private var fileCard: some View {
        HStack(spacing: 16) {
            FileTile(ext: MockData.incomingFileExt, hue: 0.55)
                .frame(width: 76, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text(MockData.incomingFileName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MeshDropColor.dpaper)
                    .lineLimit(1)
                Text(MockData.incomingFileBytes)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaperMute)
                HStack(spacing: 8) {
                    Chip(text: "● E2E", tone: .lime, mono: true, size: 13)
                    Chip(text: "9ms · LAN", tone: .outline, mono: true, size: 13)
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

    private var remoteHint: some View {
        RemoteHint(items: [
            .init(glyph: "← →", label: "切换缩略图"),
            .init(glyph: "OK",  label: "接收并播放"),
            .init(glyph: "▶︎", label: "幻灯片"),
            .init(glyph: "TV", label: "返回"),
        ])
    }
}
