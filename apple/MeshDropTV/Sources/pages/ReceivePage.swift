import SwiftUI

struct ReceivePage: View {
    @State private var selected: Int = MockData.incomingFromIndex
    @FocusState private var focusedThumb: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 36) {
            VStack(alignment: .leading, spacing: 22) {
                heroPhoto
                thumbnailStrip
                    .focusSection()
                Spacer(minLength: 0)
                remoteHint
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            sidePanel
                .frame(width: 460)
                .focusSection()
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
                InvisibleFocusButton(isFocused: $focusedThumb, value: item.id) {
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
                                .strokeBorder(MeshDropColor.dpaper.opacity(focusedThumb == item.id ? 0.95 : 0.0), lineWidth: 2.5)
                        )
                        .offset(y: focusedThumb == item.id ? -6 : 0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: focusedThumb)
                }
            }
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
                CTAButton(title: "接收并播放", subtitle: "OK · 同时进入幻灯片", tone: .lime, fillWidth: true)
                HStack(spacing: 14) {
                    CTAButton(title: "仅保存", subtitle: "SAVE",  tone: .ink, fillWidth: true)
                    CTAButton(title: "不接收", subtitle: "REJECT", tone: .mute, fillWidth: true)
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
