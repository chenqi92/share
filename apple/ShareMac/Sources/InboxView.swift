import SwiftUI
import ShareKit

/// 底部"收件"展开区。最新一条置顶；右上角"清空"。
struct InboxView: View {
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        if engine.inbox.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("收件")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("清空", action: engine.clearInbox)
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(engine.inbox) { item in
                            InboxRow(item: item)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .frame(maxHeight: 200)
            }
            .background(.thinMaterial)
        }
    }
}

private struct InboxRow: View {
    let item: InboxItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(item.peer.name)
                    .font(.caption.weight(.semibold))
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
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.08)))
    }
}
