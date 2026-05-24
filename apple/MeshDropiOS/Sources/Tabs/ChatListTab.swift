import SwiftUI

struct ChatListTab: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    private let recents: [MockDevice] = [Mock.devices[3], Mock.devices[2], Mock.devices[0], Mock.devices[1]]

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    AsciiDivider("ACTIVE · 进行中 · 2")
                    ForEach(recents.prefix(2)) { d in
                        chatRow(d, unread: d.id == "mengxi" ? 2 : 0,
                                last: lastLine(for: d), lastTime: "14:08")
                    }
                    AsciiDivider("RECENT · 最近")
                    ForEach(recents.dropFirst(2)) { d in
                        chatRow(d, unread: 0, last: lastLine(for: d), lastTime: "13:42")
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                MeshDropLockup(size: 17)
            }
            ToolbarItem(placement: .topBarTrailing) {
                IconBtn("square.and.pencil", size: 30, variant: .ghost) {
                    state.showSendSheet = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("聊天")
                .font(MeshDropFont.display(28, weight: .bold))
            Text("Chats.")
                .font(MeshDropFont.display(18, weight: .semibold))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink60)
        }
    }

    private func chatRow(_ d: MockDevice, unread: Int, last: String, lastTime: String) -> some View {
        NavigationLink(value: d.id) {
            HStack(spacing: 12) {
                Avatar(initials: d.initials, color: d.color, size: 42,
                       ring: unread > 0 ? .lime : .none, online: d.isOnline)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(d.who)
                            .font(MeshDropFont.body(15, weight: .semibold))
                            .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                        KindGlyph(d.kind, size: 10)
                        Spacer(minLength: 4)
                        Text(lastTime)
                            .font(MeshDropFont.mono(10))
                            .foregroundStyle(muted)
                    }
                    HStack(spacing: 6) {
                        Text(last)
                            .font(MeshDropFont.body(13))
                            .foregroundStyle(muted)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if unread > 0 {
                            Text("\(unread)")
                                .font(MeshDropFont.mono(11, weight: .bold))
                                .foregroundStyle(MeshDropColor.ink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(MeshDropColor.lime))
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            state.selectedDeviceID = d.id
        })
        .navigationDestination(for: String.self) { id in
            ChatDetailScreen(device: Mock.devices.first(where: { $0.id == id }) ?? d)
        }
    }

    private func lastLine(for d: MockDevice) -> String {
        switch d.id {
        case "mengxi": return "这几张供参考"
        case "jiawei": return "规划文档_v0.3.pages · 3.4 MB"
        case "lily":   return "改完了，整理一下发你"
        case "kun":    return "IMG_4821~38.heic · 接收中 12%"
        default:        return "—"
        }
    }

    private var muted: Color { scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45 }
}
