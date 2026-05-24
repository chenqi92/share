import SwiftUI
import ShareKit

struct InboxView: View {
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        if engine.inbox.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("收件")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("清空", action: engine.clearInbox)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(engine.inbox) { item in
                            InboxRow(item: item)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 12)
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
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(12)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
