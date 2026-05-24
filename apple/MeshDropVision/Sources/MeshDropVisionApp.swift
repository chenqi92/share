import SwiftUI

@main
struct MeshDropVisionApp: App {

    @State private var tab: AppTab = .nearby

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView(tab: $tab)
                .frame(minWidth: 1600, idealWidth: 1800, maxWidth: .infinity,
                       minHeight: 1000, idealHeight: 1100, maxHeight: .infinity)
                .preferredColorScheme(.dark)
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
struct RootView: View {
    @Binding var tab: AppTab

    var body: some View {
        ZStack {
            switch tab {
            case .nearby:
                SpatialNearbyPage()
                    .transition(.opacity)
            case .chats:
                // 不在 4 张截图清单里，但 tab 仍能切到 — 给一个 spatial 的对话列表 stub。
                ConversationsPage()
            case .transfers:
                TransfersPage()
            case .pairing:
                PairingPage()
            }
        }
        .animation(.easeInOut(duration: 0.28), value: tab)
    }
}

/// 对话页：极简 spatial 列表（4 张 glass mini-card 漂浮在中央）。
struct ConversationsPage: View {
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
                        Chip(text: "● 4 PEERS", tone: .lime, mono: true)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                    ForEach(MockData.conversations) { c in
                        let peer = MockData.device(c.peerId)
                        HStack(spacing: 14) {
                            Avatar(initials: peer.initials, color: peer.color, size: 38)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(peer.who)
                                        .font(MDFont.cardTitle).foregroundStyle(MD.dpaper)
                                    KindGlyph(kind: peer.kind, size: 11)
                                    Spacer()
                                    Text(c.time)
                                        .font(MDFont.micro).mdMonoTracking()
                                        .foregroundStyle(MD.dpaper.opacity(0.55))
                                }
                                Text(c.lastSnippet)
                                    .font(MDFont.body)
                                    .foregroundStyle(MD.dpaper.opacity(0.72))
                                    .lineLimit(1)
                            }
                            if c.unread > 0 {
                                Text("\(c.unread)")
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(MD.ink)
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(MD.lime))
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
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
}
