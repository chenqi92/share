import SwiftUI
import MeshDropKit

struct ChatListTab: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme

    /// 去重 / 合并一律按 fingerprint（稳定身份），不按 id。
    /// 原因：LAN 实时设备的 id = 对端运行时 Identity.id，而历史项落盘重建时 id 用 fp 兜底
    /// （History.swift），同一台设备这两个 id 永不相等 —— 按 id 去重会让"在线那台"和
    /// "历史里那台"并列成两行。先放 displayDevices（在线优先胜出），历史项补充离线设备。
    private func mergeKey(_ device: MockDevice) -> String {
        device.fingerprint.isEmpty ? device.id : device.fingerprint
    }

    private var devices: [MockDevice] {
        var seen = Set<String>()
        var merged: [MockDevice] = []

        func append(_ device: MockDevice) {
            let key = mergeKey(device)
            guard !seen.contains(key) else { return }
            seen.insert(key)
            merged.append(device)
        }

        engine.displayDevices.forEach(append)
        engine.history
            .sorted { $0.createdAt > $1.createdAt }
            .forEach { item in
                append(item.peer.displayMock(isOnline: false))
            }
        return merged
    }

    /// 用最近 history 中出现过的 peer + 当前 LAN 设备合并，按"是否有近期消息"排序。
    private var recents: [(device: MockDevice, lastMsg: String?, lastTime: String?, unread: Int)] {
        let history = engine.history
        return devices.map { d in
            let key = mergeKey(d)
            let related = history.first(where: { $0.peer.fingerprint == key })
            return (d, ChatListTab.previewLine(related),
                    related.map { HistoryItem.timeFormatter.string(from: $0.createdAt) },
                    engine.unreadByPeer[d.id] ?? 0)
        }
    }

    static func previewLine(_ item: HistoryItem?) -> String? {
        guard let item else { return nil }
        switch item.kind {
        case .text(let t):
            return t.count > 24 ? String(t.prefix(24)) + "…" : t
        case .file(let name, let size, _):
            return "\(name) · \(HistoryItem.byteFormatter.string(fromByteCount: Int64(size)))"
        }
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if devices.isEmpty {
                        emptyCard
                    } else {
                        let active = recents.filter { $0.lastMsg != nil }
                        let rest = recents.filter { $0.lastMsg == nil }
                        if !active.isEmpty {
                            AsciiDivider(MD("chatList.section.active", active.count))
                            ForEach(active, id: \.device.id) { r in
                                chatRow(r.device, unread: r.unread,
                                        last: r.lastMsg ?? "—", lastTime: r.lastTime ?? "")
                            }
                        }
                        if !rest.isEmpty {
                            AsciiDivider(MD("chatList.section.recent"))
                            ForEach(rest, id: \.device.id) { r in
                                chatRow(r.device, unread: 0, last: "—", lastTime: "")
                            }
                        }
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { state.showClipboardSheet = true } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                Button { state.presentSend(.text) } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .navigationDestination(for: String.self) { id in
            ChatDetailScreen(device: deviceForChat(id) ?? MockDevice.placeholder)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(MD("chatList.title"))
                .font(MeshDropFont.display(28, weight: .bold))
            Text(MD("chatList.subtitle"))
                .font(MeshDropFont.display(18, weight: .semibold))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink60)
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Text(MD("chatList.empty.title"))
                .font(MeshDropFont.body(14, weight: .semibold))
            Text(MD("chatList.empty.subtitle"))
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
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
            engine.markRead(peerID: d.id)
        })
    }

    private func deviceForChat(_ id: String) -> MockDevice? {
        engine.displayDevices.first(where: { $0.id == id })
        ?? engine.history.first(where: { $0.peer.id == id })?.peer.displayMock(isOnline: false)
    }

    private var muted: Color { scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45 }
}
