import SwiftUI
import MeshDropKit

@main
struct MeshDropVisionApp: App {

    @State private var tab: AppTab = .nearby
    @StateObject private var engine = ShareEngine.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(tab: $tab)
                .environmentObject(engine)
                .frame(minWidth: 1600, idealWidth: 1800, maxWidth: .infinity,
                       minHeight: 1000, idealHeight: 1100, maxHeight: .infinity)
                .preferredColorScheme(.dark)
                .onAppear {
                    engine.start()
                }
                .ornament(attachmentAnchor: .scene(.bottom)) {
                    TabOrnament(current: $tab)
                        .padding(.bottom, 20)
                }
        }
        .windowStyle(.plain)        // 让窗口本身没有默认 chrome,我们自己画
        .defaultSize(width: 1800, height: 1100)
    }
}

/// 顶层视图：根据当前 tab 切换页面。
/// 入站文件 offer / 配对请求会作为 overlay 弹在任意页面之上。
struct RootView: View {
    @Binding var tab: AppTab
    @EnvironmentObject private var engine: ShareEngine

    var body: some View {
        ZStack {
            switch tab {
            case .nearby:
                SpatialNearbyPage()
                    .transition(.opacity)
            case .chats:
                ConversationsPage()
            case .transfers:
                TransfersPage()
            case .pairing:
                PairingPage()
            }

            // 真事件：入站文件 offer 覆盖在任意页面之上
            if !engine.pendingFileOffers.isEmpty {
                ReceiveCardScreen()
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(80)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: tab)
        .animation(.spring(response: 0.35, dampingFraction: 0.85),
                   value: engine.pendingFileOffers.count)
    }
}

/// 对话页：按 peer 折叠 `engine.history`，每个 peer 一张玻璃 mini-card。
struct ConversationsPage: View {
    @EnvironmentObject private var engine: ShareEngine

    private struct Conversation: Identifiable {
        let id: String     // peer.id
        let peer: Device
        let lastSnippet: String
        let lastAt: Date
        let unread: Int    // 简易：未读 = incoming + 未读 stub 0；当前 history 无 read 标记，统一显示 0
    }

    private var conversations: [Conversation] {
        var grouped: [String: [HistoryItem]] = [:]
        for item in engine.history {
            grouped[item.peer.id, default: []].append(item)
        }
        return grouped.compactMap { _, items -> Conversation? in
            guard let latest = items.max(by: { $0.createdAt < $1.createdAt }) else { return nil }
            let snippet: String
            switch latest.kind {
            case .text(let body):
                snippet = body
            case .file(let name, let bytes, _):
                let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
                snippet = "[文件 · \(name) · \(sizeStr)]"
            }
            return Conversation(
                id: latest.peer.id,
                peer: latest.peer,
                lastSnippet: snippet,
                lastAt: latest.createdAt,
                unread: 0
            )
        }
        .sorted { $0.lastAt > $1.lastAt }
    }

    var body: some View {
        GeometryReader { geo in
            let canvas = geo.size
            ZStack {
                MDPassthroughBackground(hue: 200)

                VStack(spacing: 14) {
                    HStack {
                        Text("对话 · CONVERSATIONS")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(MD.dpaper)
                        Spacer()
                        Chip(text: "● \(engine.devices.count) PEERS", tone: .lime, mono: true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                    if conversations.isEmpty {
                        emptyHint
                            .padding(.top, 60)
                    } else {
                        ForEach(conversations) { c in
                            let mock = LivePeerMapper.mockDevice(from: c.peer, index: 0, total: 1)
                            HStack(spacing: 14) {
                                Avatar(initials: mock.initials, color: mock.color, size: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(mock.who)
                                            .font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
                                        KindGlyph(kind: mock.kind, size: 11)
                                        Spacer()
                                        Text(timeLabel(c.lastAt))
                                            .font(MDFont.micro).mdMonoTracking()
                                            .foregroundStyle(MD.dpaper.opacity(0.55))
                                    }
                                    Text(c.lastSnippet)
                                        .font(MDFont.body)
                                        .foregroundStyle(MD.dpaper.opacity(0.72))
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                        }
                    }
                    Spacer()
                }
                .frame(width: 560)
                .background(
                    GlassCard(corner: 28) {
                        Color.clear
                    }
                )
                .position(x: canvas.width / 2, y: canvas.height / 2)

                StatusOrnament()
                    .position(x: canvas.width / 2, y: 44)
                TabOrnamentStatic(current: .chats)
                    .position(x: canvas.width / 2, y: canvas.height - 50)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 6) {
            Text("还没有对话")
                .font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
            Text("EMPTY · 发一段文本或文件来开始")
                .font(MDFont.microHi).tracking(1.6)
                .foregroundStyle(MD.dpaper.opacity(0.6))
        }
    }

    private func timeLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
