import SwiftUI
import AppKit
import ShareKit

/// 底部"历史"区：双向显示发送/接收。可单条删除，可清空全部。
/// 收 / 发用颜色和箭头方向区分。
struct HistoryView: View {
    @EnvironmentObject var engine: ShareEngine

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(engine.history) { item in
                        HistoryRow(item: item)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 280)
        }
        .background(.thickMaterial)
        .overlay(alignment: .top) { Divider().opacity(0.5) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.tint)
            Text("历史")
                .font(.headline)
            Text("\(engine.history.count)")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
            Spacer()
            Button(action: engine.clearHistory) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("清空历史")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private struct HistoryRow: View {
    @EnvironmentObject var engine: ShareEngine
    let item: HistoryItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 方向图标
            ZStack {
                Circle()
                    .fill(item.direction == .outgoing
                          ? Color.blue.opacity(0.15)
                          : Color.green.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: item.direction == .outgoing
                      ? "arrow.up.right"
                      : "arrow.down.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.direction == .outgoing ? Color.blue : Color.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                // 头部：方向 + 对端名 + 时间
                HStack(spacing: 6) {
                    Text(item.direction == .outgoing ? "发送到" : "来自")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(item.peer.name)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(item.createdAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // 内容（按 kind 渲染）
                contentView

                // 状态条
                statusView
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contextMenu {
            if case .file(_, _, let url) = item.kind, let u = url {
                Button("在 Finder 中显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([u])
                }
            }
            if case .text(let s) = item.kind {
                Button("复制文本") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(s, forType: .string)
                }
            }
            Divider()
            Button("删除", role: .destructive) {
                engine.removeHistoryItem(item.id)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch item.kind {
        case .text(let s):
            Text(s)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(6)
        case .file(let name, let size, _):
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(byteString(size))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .pending, .waitingApproval:
            Label(item.status == .pending ? "准备中…" : "等待对方接受…",
                  systemImage: "ellipsis.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)

        case .transferring(let done, let total):
            VStack(alignment: .leading, spacing: 3) {
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .progressViewStyle(.linear)
                Text("\(byteString(done)) / \(byteString(total))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .completed:
            Label("完成", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)

        case .failed(let reason):
            Label(reason, systemImage: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.red)

        case .canceled:
            Label("已取消", systemImage: "xmark.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func byteString(_ n: UInt64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: Int64(n))
    }
}
