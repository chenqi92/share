import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ChatPage: View {
    @EnvironmentObject var state: AppState
    var forceDragOverlay: Bool = false
    @State private var composer: String = "那我去过一遍标注，主要看 §2.3 那段"

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                Divider()
                    .background(MeshDropColor.divider)
                ZStack {
                    messages
                    if forceDragOverlay { dropOverlay }
                }
                composerBar
            }
            .background(MeshDropColor.background)
        }
    }

    private var dev: MockDevice { state.selectedDevice }

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(initials: dev.initials, color: dev.color, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(dev.who) · \(dev.name)")
                    .font(MeshDropFont.body(size: 14.5, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                HStack(spacing: 5) {
                    KindGlyph(kind: dev.kind, size: 11)
                    Text(dev.os).font(MeshDropFont.mono(size: 10)).foregroundStyle(MeshDropColor.textMuted)
                    Text("·").foregroundStyle(MeshDropColor.textMuted)
                    Circle().fill(MeshDropColor.limeDeep).frame(width: 5, height: 5)
                    Text("ONLINE").meshTag().foregroundStyle(MeshDropColor.limeDeep)
                    Text("·").foregroundStyle(MeshDropColor.textMuted)
                    Text("\(dev.rtt)ms").font(MeshDropFont.mono(size: 10)).foregroundStyle(MeshDropColor.textMuted)
                    Text("·").foregroundStyle(MeshDropColor.textMuted)
                    Text("E2E").meshTag().foregroundStyle(MeshDropColor.limeDeep)
                    Text("·").foregroundStyle(MeshDropColor.textMuted)
                    Text("192.168.1.78").font(MeshDropFont.mono(size: 10)).foregroundStyle(MeshDropColor.textMuted)
                }
            }
            Spacer()
            Chip(text: "已配对 · Paired", tone: .lime, mono: false)
            IconBtn(systemName: "ellipsis", size: 28)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(MeshDropColor.background)
    }

    private var messages: some View {
        PageScroll {
            VStack(spacing: 14) {
                AsciiDivider(text: "TODAY · 14:08")

                MsgBubble(side: .incoming, time: "14:08") {
                    Text("下午发的那版改完了吗？想看下 §2.3 的笔记。")
                        .font(MeshDropFont.body(size: 13))
                }

                MsgBubble(side: .outgoing, time: "14:09", delivered: true) {
                    Text("改完了，整理一下发你 👇")
                        .font(MeshDropFont.body(size: 13))
                }

                MsgBubble(side: .outgoing, kind: .file, time: "14:10", delivered: true) {
                    FileChip(name: "设计稿_v3_final.fig",
                             size: "14.2 MB · ✓ SHA-256 verified",
                             ext: "fig",
                             dark: false)
                        .frame(width: 280)
                }

                MsgBubble(side: .incoming, time: "14:11") {
                    Text("收到，我看看~ 这边晚一点也发你两张参考图。")
                        .font(MeshDropFont.body(size: 13))
                }

                MsgBubble(side: .incoming, kind: .image, time: "14:14") {
                    HStack(spacing: 4) {
                        Photo(hue: 24).frame(width: 120, height: 90)
                        Photo(hue: 200).frame(width: 120, height: 90)
                    }
                }

                MsgBubble(side: .incoming, kind: .file, time: "14:18") {
                    FileChip(name: "iOS-mocks-final.zip",
                             size: "48.6 MB · 67%",
                             ext: "zip",
                             progress: 0.67)
                        .frame(width: 280)
                }

                // 浮窗 receive confirm
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Text("↓").foregroundStyle(MeshDropColor.sky).meshMono(11, weight: .bold)
                        Text("来自 孟茜 的传输 · incoming")
                            .font(MeshDropFont.body(size: 11.5, weight: .semibold))
                            .foregroundStyle(MeshDropColor.textPrimary)
                        Spacer()
                        Text("刚刚")
                            .font(MeshDropFont.mono(size: 10))
                            .foregroundStyle(MeshDropColor.textMuted)
                    }
                    FileChip(name: "iOS-mocks-final.zip",
                             size: "48.6 MB · 1 个文件",
                             ext: "zip")
                    HStack(spacing: 8) {
                        Spacer()
                        Text("拒绝 · Reject")
                            .font(MeshDropFont.body(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(MeshDropColor.divider, lineWidth: 1)
                            )
                            .foregroundStyle(MeshDropColor.textSecondary)
                        Text("接收 · Accept ⏎")
                            .font(MeshDropFont.body(size: 12, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(MeshDropColor.lime)
                            )
                            .foregroundStyle(MeshDropColor.ink)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(MeshDropColor.limeFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(MeshDropColor.lime, lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            IconBtn(systemName: "paperclip", size: 32, action: { pickFiles(imagesOnly: false) })
            IconBtn(systemName: "photo", size: 32, action: { pickFiles(imagesOnly: true) })
            HStack {
                Text(composer.isEmpty
                     ? "发送给 \(dev.who) · 拖入即送 / ⏎ 发送"
                     : composer)
                    .font(MeshDropFont.body(size: 13))
                    .foregroundStyle(composer.isEmpty
                                     ? MeshDropColor.textMuted
                                     : MeshDropColor.textPrimary)
                    .lineLimit(2)
                Spacer()
                Text("⏎")
                    .font(MeshDropFont.mono(size: 10, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textMuted)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(MeshDropColor.divider, lineWidth: 0.5)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(MeshDropColor.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(MeshDropColor.divider, lineWidth: 1)
                    )
            )
            IconBtn(systemName: "arrow.up", size: 32, accent: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var dropOverlay: some View {
        ZStack {
            MeshDropColor.lime.opacity(0.42)
            VStack(spacing: 14) {
                Text("⤓")
                    .font(MeshDropFont.display(size: 60, weight: .bold))
                    .foregroundStyle(MeshDropColor.ink)
                Text("放手即发 · Drop to send")
                    .font(MeshDropFont.display(size: 28, weight: .bold))
                    .foregroundStyle(MeshDropColor.ink)
                Text(state.dragFileSummary)
                    .font(MeshDropFont.mono(size: 13, weight: .semibold))
                    .foregroundStyle(MeshDropColor.ink)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(MeshDropColor.ink, style: StrokeStyle(lineWidth: 2, dash: [10, 6]))
                .padding(16)
        )
    }

    /// 弹 NSOpenPanel 让用户多选文件（imagesOnly=true 时限定图片类型），
    /// 选完后 batch 发给当前选中设备。
    private func pickFiles(imagesOnly: Bool) {
        guard !state.selectedDeviceID.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.title = imagesOnly ? "选择图片" : "选择文件"
        panel.prompt = "发送"
        if imagesOnly {
            panel.allowedContentTypes = [.image]
        }
        if panel.runModal() == .OK {
            let urls = panel.urls
            if !urls.isEmpty {
                state.sendFiles(toDeviceID: state.selectedDeviceID, fileURLs: urls)
            }
        }
    }
}
