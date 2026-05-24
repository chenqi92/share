import SwiftUI
import ShareKit

/// 底部"收件"展开区。玻璃 + 圆角列表，最新一条置顶。
struct InboxView: View {
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "tray.fill")
                    .foregroundStyle(.tint)
                Text("收件")
                    .font(.headline)
                Text("\(engine.inbox.count)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Button(action: engine.clearInbox) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("清空收件箱")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider().opacity(0.4)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(engine.inbox) { item in
                        InboxRow(item: item)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 240)
        }
        .background(.thickMaterial)
        .overlay(alignment: .top) {
            Divider().opacity(0.5)
        }
    }
}

private struct InboxRow: View {
    let item: InboxItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon(for: item.peer.os))
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text(item.peer.name)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(item.receivedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            switch item.kind {
            case .text(let content):
                Text(content)
                    .font(.body)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func icon(for os: DeviceOS) -> String {
        switch os {
        case .ios:     return "iphone"
        case .android: return "candybarphone"
        case .macos:   return "macbook"
        case .windows: return "pc"
        case .linux:   return "desktopcomputer"
        }
    }
}
