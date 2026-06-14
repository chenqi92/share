import AppKit
import SwiftUI
import UniformTypeIdentifiers
import MeshDropKit

struct ChatPage: View {
    @EnvironmentObject var state: AppState
    var forceDragOverlay: Bool = false
    @State private var composer: String = ""

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
    private var canSend: Bool { state.canSendToSelectedDevice }

    /// 当前对话 = engine.history 中 peer.id 匹配选中设备的所有项，按时间正序展示。
    private var conversation: [HistoryItem] {
        state.engineHistoryItems
            .filter { $0.peer.id == state.selectedDeviceID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Avatar(initials: dev.initials, color: dev.color, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(dev.who)
                    .font(MeshDropFont.body(size: 14.5, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                HStack(spacing: 5) {
                    KindGlyph(kind: dev.kind, size: 11)
                    Text(dev.os).font(MeshDropFont.mono(size: 10)).foregroundStyle(MeshDropColor.textMuted)
                    Text("·").foregroundStyle(MeshDropColor.textMuted)
                    Circle()
                        .fill(dev.online ? MeshDropColor.limeDeep : MeshDropColor.textMuted)
                        .frame(width: 5, height: 5)
                    Text(dev.online ? "ONLINE" : "OFFLINE")
                        .meshTag()
                        .foregroundStyle(dev.online ? MeshDropColor.limeDeep : MeshDropColor.textMuted)
                    if dev.rtt > 0 {
                        Text("·").foregroundStyle(MeshDropColor.textMuted)
                        Text("\(dev.rtt)ms").font(MeshDropFont.mono(size: 10)).foregroundStyle(MeshDropColor.textMuted)
                    }
                    Text("·").foregroundStyle(MeshDropColor.textMuted)
                    // v0.1 明文 LAN，不宣称 E2E。
                    Text("LAN").meshTag().foregroundStyle(MeshDropColor.textMuted)
                }
            }
            Spacer()
            IconBtn(systemName: "ellipsis", size: 28)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(MeshDropColor.background)
    }

    private var messages: some View {
        PageScroll {
            VStack(spacing: 14) {
                if conversation.isEmpty {
                    emptyHint
                } else {
                    ForEach(conversation) { item in
                        bubble(for: item)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Text(state.selectedDeviceID.isEmpty ? "还没有可对话的设备" : "还没有消息")
                .font(MeshDropFont.body(size: 13, weight: .semibold))
                .foregroundStyle(MeshDropColor.textPrimary)
            Text(emptyDetail)
                .font(MeshDropFont.mono(size: 11))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var emptyDetail: String {
        if state.selectedDeviceID.isEmpty { return "等待同一局域网的设备出现" }
        return canSend ? "发一句话开始对话" : "设备已离线 · 历史仍保留"
    }

    @ViewBuilder
    private func bubble(for item: HistoryItem) -> some View {
        let side: BubbleSide = item.direction == .outgoing ? .outgoing : .incoming
        let time = Self.timeFormatter.string(from: item.createdAt)
        switch item.kind {
        case .text(let content):
            MsgBubble(side: side, time: time, delivered: isDelivered(item)) {
                Text(content)
                    .font(MeshDropFont.body(size: 13))
                    .textSelection(.enabled)
            }
        case .file(let name, let size, let url):
            if isImageFile(name: name, url: url) {
                MsgBubble(side: side, kind: .image, time: time, delivered: isDelivered(item)) {
                    VStack(alignment: .leading, spacing: 6) {
                        ImagePreview(url: url, base64: nil, cornerRadius: 12)
                            .frame(width: 280, height: 188)
                        HStack(spacing: 6) {
                            Text(name)
                                .font(MeshDropFont.body(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("· \(fileSizeLabel(size: size, status: item.status))")
                                .font(MeshDropFont.mono(size: 10.5))
                                .opacity(0.65)
                        }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 4)
                    }
                    .frame(width: 288)
                }
            } else {
                MsgBubble(side: side, kind: .file, time: time, delivered: isDelivered(item)) {
                    FileChip(name: name,
                             size: fileSizeLabel(size: size, status: item.status),
                             ext: fileExt(name),
                             progress: progressFraction(item.status),
                             dark: side == .outgoing)
                        .frame(width: 280)
                }
            }
        }
    }

    private var composerBar: some View {
        HStack(spacing: 10) {
            IconBtn(systemName: "paperclip", size: 32, action: { pickFiles(imagesOnly: false) })
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
            IconBtn(systemName: "photo", size: 32, action: { pickFiles(imagesOnly: true) })
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
            HStack {
                TextField(
                    composerPlaceholder,
                    text: $composer
                )
                .textFieldStyle(.plain)
                .font(MeshDropFont.body(size: 13))
                .foregroundStyle(MeshDropColor.textPrimary)
                .onSubmit(sendComposed)
                .disabled(!canSend)
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
            IconBtn(systemName: "arrow.up", size: 32, accent: true, action: sendComposed)
                .disabled(!canSend)
                .opacity(canSend ? 1 : 0.45)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    private var composerPlaceholder: String {
        if state.selectedDeviceID.isEmpty { return "等待设备…" }
        if !canSend { return "设备已离线 · 历史仍保留" }
        return "发送给 \(dev.who) · 拖入即送 / ⏎ 发送"
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

    // MARK: - 发送

    private func sendComposed() {
        let trimmed = composer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, canSend else { return }
        state.sendText(toDeviceID: state.selectedDeviceID, content: trimmed)
        composer = ""
    }

    /// 弹 NSOpenPanel 让用户多选文件（imagesOnly=true 时限定图片类型），
    /// 选完后 batch 发给当前选中设备。
    private func pickFiles(imagesOnly: Bool) {
        guard canSend else { return }
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

    // MARK: - 投影辅助

    private func isDelivered(_ item: HistoryItem) -> Bool {
        item.direction == .outgoing && item.status == .completed
    }

    private func progressFraction(_ status: TransferStatus) -> Double? {
        if case let .transferring(done, total) = status, total > 0 {
            return Double(done) / Double(total)
        }
        return nil
    }

    private func fileSizeLabel(size: UInt64, status: TransferStatus) -> String {
        let base = Self.byteFormatter.string(fromByteCount: Int64(size))
        switch status {
        case .completed:
            return "\(base) · ✓ SHA-256 verified"
        case let .transferring(done, total) where total > 0:
            return "\(base) · \(Int(Double(done) / Double(total) * 100))%"
        case .waitingApproval, .pending:
            return "\(base) · 等待中"
        case .failed:
            return "\(base) · 失败"
        case .canceled:
            return "\(base) · 已取消"
        default:
            return base
        }
    }

    private func fileExt(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        return ext.isEmpty ? "bin" : ext
    }

    private func isImageFile(name: String, url: URL?) -> Bool {
        if let url {
            let values = try? url.resourceValues(forKeys: [.contentTypeKey])
            if values?.contentType?.conforms(to: .image) == true { return true }
        }
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty else { return false }
        return UTType(filenameExtension: ext)?.conforms(to: .image) == true
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()
}
