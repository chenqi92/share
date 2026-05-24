import SwiftUI

struct HistoryPage: View {
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
                    Chip(text: "12 ITEMS", tone: .outline, mono: true)
                    Chip(text: "2.41 GB",  tone: .outline, mono: true)
                }

                AsciiDivider(text: "TODAY · 今天 · 6 件")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(MockHistory.all) { h in
                        historyCard(h)
                    }
                }

                AsciiDivider(text: "YESTERDAY · 昨天 · 4 件")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<3) { i in
                        yesterdayCard(i)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
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
                HStack(spacing: 4) {
                    Photo(hue: 24).frame(width: 60, height: 60)
                    Photo(hue: 200).frame(width: 60, height: 60)
                    Photo(hue: 90).frame(width: 60, height: 60)
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
    }

    @ViewBuilder
    private func yesterdayCard(_ i: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(i == 0 ? "↑" : "↓")
                    .font(MeshDropFont.mono(size: 14, weight: .bold))
                    .foregroundStyle(i == 0 ? MeshDropColor.flame : MeshDropColor.sky)
                Text(["李莉", "孟茜", "DEV-01"][i])
                    .font(MeshDropFont.body(size: 12, weight: .semibold))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Spacer()
                Text(["18:42", "16:08", "11:24"][i])
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            FileChip(
                name: ["proposal.pdf", "logo-export.zip", "build-2026.05.23.dmg"][i],
                size: ["1.2 MB", "8.4 MB", "182 MB"][i],
                ext: ["pdf", "zip", "dmg"][i]
            )
            Chip(text: "DONE", tone: .lime, mono: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeshDropColor.cardBg)
        )
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
