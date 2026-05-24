import SwiftUI
import MeshDropKit

struct ChatDetailScreen: View {
    let device: MockDevice
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme
    @State private var composerText: String = ""

    /// 当前对话 = engine.history 中 peer.id 匹配的所有项，按时间正序展示。
    private var messages: [MockMessage] {
        engine.history
            .filter { $0.peer.id == device.id }
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.displayMessage }
    }

    /// 收到本 peer 的 file offer 时自动弹 FileOfferSheet（之前 mock 是 timer，现在是真事件）。
    private var incomingOffer: PendingFileOffer? {
        engine.pendingFileOffers.first(where: { $0.peer.id == device.id })
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    chatHeader
                    if messages.isEmpty {
                        emptyHint
                    } else {
                        AsciiDivider("TODAY · 今天")
                        ForEach(messages) { m in
                            MsgBubble(m)
                        }
                    }
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            composer
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Avatar(initials: device.initials, color: device.color, size: 26, online: device.isOnline)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(device.who)
                            .font(MeshDropFont.body(14, weight: .semibold))
                        Text("\(device.os) · \(device.rtt)ms · E2E")
                            .font(MeshDropFont.mono(9.5))
                            .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                IconBtn("ellipsis", size: 30, variant: .ghost)
            }
        }
        .onChange(of: incomingOffer?.id) { _, newID in
            if newID != nil { state.showOfferSheet = true }
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 8) {
            Chip(device.isOnline ? "ONLINE" : "OFFLINE",
                 tone: device.isOnline ? .lime : .outline,
                 mono: true, uppercased: true, icon: "circle.fill")
            Chip("E2E", tone: .outline, mono: true, uppercased: true)
            Spacer()
            Text("RTT \(device.rtt)ms")
                .font(MeshDropFont.mono(10))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Text("还没有消息")
                .font(MeshDropFont.body(13, weight: .semibold))
            Text("发一句你好开始对话")
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                IconBtn("paperclip", size: 32, variant: .ghost) { state.showSendSheet = true }
                IconBtn("photo", size: 32, variant: .ghost) { state.showSendSheet = true }
            }

            HStack {
                if composerText.isEmpty {
                    Text("想说点什么…")
                        .font(MeshDropFont.body(14))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                }
                TextField("", text: $composerText)
                    .font(MeshDropFont.body(14))
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit(sendComposed)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
            )
            .overlay(
                Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )

            Button(action: sendComposed) {
                IconBtn("arrow.up", size: 38, variant: .lime, shape: .circle)
            }
            .buttonStyle(.plain)
            .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            (scheme == .dark ? MeshDropColor.dink.opacity(0.92) : MeshDropColor.paper.opacity(0.92))
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line).frame(height: 0.5)
        }
    }

    private func sendComposed() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let real = engine.realDevice(for: device.id) else { return }
        engine.sendText(to: real, content: trimmed)
        composerText = ""
    }
}
