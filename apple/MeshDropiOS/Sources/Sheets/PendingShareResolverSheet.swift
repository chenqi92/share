import SwiftUI
import MeshDropKit

/// 待发分享「选目标」面板。
///
/// 来源：iOS Share Extension 把分享内容写入 App Group 队列时，目标 peer 还未确定
/// （扩展进程看不到 LAN 设备）。主 app 启动 / 回前台时检测到有未决项就弹这个面板，
/// 让用户对每条未决项挑一个**当前已发现**的设备，挑完即经 engine 发出并从队列移除。
struct PendingShareResolverSheet: View {
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.dismiss) private var dismiss

    /// 待解析的未决项（由 RootView 在出现时载入）。
    @State var items: [PendingShareQueue.ResolvedPendingItem]

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(items) { resolved in
                                itemRow(resolved)
                            }
                        } header: {
                            Text("从「分享」收到 \(items.count) 项 · 选择发送目标")
                        } footer: {
                            if engine.devices.isEmpty {
                                Text("附近暂无设备。确保对方在同一 Wi-Fi 且打开了 MeshDrop，设备出现后即可选择。")
                            }
                        }
                    }
                }
            }
            .navigationTitle("待发送")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func itemRow(_ resolved: PendingShareQueue.ResolvedPendingItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: glyph(for: resolved.item))
                    .foregroundStyle(MeshDropColor.flame)
                VStack(alignment: .leading, spacing: 2) {
                    Text(resolved.item.summary)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    if let size = resolved.item.sizeBytes {
                        Text(HistoryItem.byteFormatter.string(fromByteCount: Int64(size)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if engine.devices.isEmpty {
                Text("等待设备…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                // 每个在线设备一个发送按钮（横向滚动避免拥挤）。
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(engine.devices) { device in
                            Button {
                                send(resolved, to: device)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.caption2)
                                    Text(device.name)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(MeshDropColor.flame.opacity(0.15)))
                                .foregroundStyle(MeshDropColor.flame)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                discard(resolved)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("没有待发送的分享")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func glyph(for item: PendingShareQueue.PendingItem) -> String {
        switch item.kind {
        case .text:  return "text.alignleft"
        case .file:  return "doc.fill"
        }
    }

    private func send(_ resolved: PendingShareQueue.ResolvedPendingItem, to device: Device) {
        PendingShareQueue.shared.send(resolved, to: device, engine: engine)
        items.removeAll { $0.id == resolved.id }
        if items.isEmpty { dismiss() }
    }

    private func discard(_ resolved: PendingShareQueue.ResolvedPendingItem) {
        PendingShareQueue.shared.discard(resolved)
        items.removeAll { $0.id == resolved.id }
        if items.isEmpty { dismiss() }
    }
}
