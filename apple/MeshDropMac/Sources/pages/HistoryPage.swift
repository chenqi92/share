import SwiftUI

struct HistoryPage: View {
    @EnvironmentObject var state: AppState
    @State private var confirmingClear = false

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("历史")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("· History")
                        .font(MeshDropFont.hero(34))
                        .tracking(-1)
                        .foregroundStyle(MeshDropColor.textMuted)
                    Spacer()
                    if !state.engineHistory.isEmpty {
                        Button { confirmingClear = true } label: {
                            Text("清空 · Clear")
                                .font(MeshDropFont.body(size: 12, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(MeshDropColor.error.opacity(0.4), lineWidth: 1)
                                )
                                .foregroundStyle(MeshDropColor.error)
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog(
                            "清空全部历史记录？此操作不可撤销。",
                            isPresented: $confirmingClear,
                            titleVisibility: .visible
                        ) {
                            Button("清空历史", role: .destructive) { state.clearHistory() }
                            Button("取消", role: .cancel) {}
                        }
                    }
                    Chip(text: "\(state.engineHistory.count) ITEMS", tone: .outline, mono: true)
                }

                if state.engineHistory.isEmpty {
                    emptyView
                } else {
                    AsciiDivider(text: "RECENT · 最近 · \(state.engineHistory.count) 件")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(state.engineHistory) { h in
                            historyCard(h)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(MeshDropColor.textMuted)
            Text("还没有历史记录")
                .font(MeshDropFont.body(size: 14, weight: .semibold))
                .foregroundStyle(MeshDropColor.textPrimary)
            Text("发出去 / 收到的传输会显示在这里")
                .font(MeshDropFont.body(size: 12))
                .foregroundStyle(MeshDropColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(MeshDropColor.cardBg)
        )
    }

    @ViewBuilder
    private func historyCard(_ h: MockHistory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(h.dir == .outgoing ? "↑" : "↓")
                    .font(MeshDropFont.mono(size: 14, weight: .bold))
                    .foregroundStyle(h.dir == .outgoing ? MeshDropColor.flame : MeshDropColor.sky)
                Text(h.peer)
                    .font(MeshDropFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Spacer()
                Text(h.time)
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            // 内容
            switch h.kind {
            case .image:
                VStack(alignment: .leading, spacing: 6) {
                    ImagePreview(url: h.fileURL, base64: nil, cornerRadius: 10)
                        .frame(height: 132)
                    if let name = h.name {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(MeshDropFont.body(size: 11.5, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let size = h.size {
                                Text("· \(size)")
                                    .font(MeshDropFont.mono(size: 10))
                                    .foregroundStyle(MeshDropColor.textMuted)
                            }
                        }
                    }
                }
            case .file:
                FileChip(name: h.name ?? "", size: h.size ?? "", ext: h.ext ?? "",
                         progress: h.progress.map { Double($0) / 100 })
            case .text:
                Text(h.content ?? "")
                    .font(MeshDropFont.body(size: 13))
                    .foregroundStyle(MeshDropColor.textPrimary)
                    .lineLimit(3)
            }
            // 状态
            HStack {
                statusBadge(h.status)
                Spacer()
                Text(h.dir == .outgoing ? "→" : "←")
                    .meshMono(11, weight: .bold)
                    .foregroundStyle(MeshDropColor.textMuted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeshDropColor.cardBg)
                .shadow(color: MeshDropColor.ink06, radius: 2, x: 0, y: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                state.removeHistoryItem(h.id)
            } label: {
                Label("删除这条记录", systemImage: "trash")
            }
        }
    }


    @ViewBuilder
    private func statusBadge(_ s: HistoryStatus) -> some View {
        switch s {
        case .done:         Chip(text: "DONE",   tone: .lime,    mono: true)
        case .transferring: Chip(text: "GOING…", tone: .flame,   mono: true)
        case .queued:       Chip(text: "QUEUED", tone: .outline, mono: true)
        case .failed:       Chip(text: "FAILED", tone: .flame,   mono: true)
        }
    }
}
