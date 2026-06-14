import SwiftUI
import MeshDropKit

struct HistoryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var engine: ShareEngine

    private var today: [MockHistoryItem] {
        let cal = Calendar.current
        return engine.history
            .filter { cal.isDateInToday($0.createdAt) }
            .map { $0.displayHistory }
    }
    private var earlier: [MockHistoryItem] {
        let cal = Calendar.current
        return engine.history
            .filter { !cal.isDateInToday($0.createdAt) }
            .map { $0.displayHistory }
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if today.isEmpty && earlier.isEmpty {
                        emptyState
                    } else {
                        AsciiDivider(MD("history.section.today", today.count))
                        if today.isEmpty {
                            Text(MD("history.today.empty"))
                                .font(MeshDropFont.mono(11))
                                .foregroundStyle(muted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        } else {
                            ForEach(today) { row($0) }
                        }
                        AsciiDivider(MD("history.section.earlier"))
                        if earlier.isEmpty {
                            emptyMore
                        } else {
                            ForEach(earlier) { row($0) }
                        }
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .navigationTitle(MD("history.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(MD("common.close")) { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if !engine.history.isEmpty {
                    Button(MD("common.clear"), role: .destructive) { engine.clearHistory() }
                }
            }
        }
    }

    private func row(_ h: MockHistoryItem) -> some View {
        HStack(spacing: 12) {
            kindIcon(h)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(h.dir == .outgoing ? "↑" : "↓")
                        .font(MeshDropFont.mono(11, weight: .bold))
                        .foregroundStyle(h.dir == .outgoing ? MeshDropColor.flame : MeshDropColor.sky)
                    Text(h.dir == .outgoing ? MD("history.dir.toPeer", h.peer) : MD("history.dir.fromPeer", h.peer))
                        .font(MeshDropFont.body(13.5, weight: .semibold))
                    Spacer()
                    Text(h.time).font(MeshDropFont.mono(10.5))
                        .foregroundStyle(muted)
                }
                content(h)
            }
            statusChip(h)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
        .contextMenu {
            Button(MD("common.delete"), role: .destructive) {
                if let id = UUID(uuidString: h.id) {
                    engine.removeHistoryItem(id)
                }
            }
        }
    }

    @ViewBuilder
    private func kindIcon(_ h: MockHistoryItem) -> some View {
        switch h.kind {
        case .file:
            FileTile(ext: h.ext ?? "?", size: 30)
        case .image:
            ZStack {
                Photo(hue: 280).frame(width: 30, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(width: 30, height: 36)
        case .text:
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(MeshDropColor.lime.opacity(0.5))
                    .frame(width: 30, height: 36)
                Image(systemName: "text.alignleft")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MeshDropColor.ink)
            }
        }
    }

    @ViewBuilder
    private func content(_ h: MockHistoryItem) -> some View {
        switch h.kind {
        case .file:
            HStack(spacing: 4) {
                Text(h.name ?? "").font(MeshDropFont.body(12)).lineLimit(1)
                Text("· \(h.size ?? "")")
                    .font(MeshDropFont.mono(10.5)).foregroundStyle(muted)
            }
        case .image:
            Text(MD("history.imageCount", h.count ?? 1)).font(MeshDropFont.body(12)).foregroundStyle(muted)
        case .text:
            Text(h.content ?? "").font(MeshDropFont.body(12)).lineLimit(1)
        }
    }

    @ViewBuilder
    private func statusChip(_ h: MockHistoryItem) -> some View {
        switch h.status {
        case .done:         Chip("✓", tone: .lime, mono: true)
        case .transferring: Chip("\(h.progress ?? 0)%", tone: .flame, mono: true)
        case .queued:       Chip("·", tone: .outline, mono: true)
        case .failed:       Chip("×", tone: .flame, mono: true)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text(MD("history.empty.title")).font(MeshDropFont.body(14, weight: .semibold))
            Text(MD("history.empty.subtitle"))
                .font(MeshDropFont.mono(11)).foregroundStyle(muted)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyMore: some View {
        VStack(spacing: 6) {
            Text(MD("history.more.empty.title")).font(MeshDropFont.body(13))
                .foregroundStyle(muted)
            Text(MD("history.more.empty.subtitle"))
                .font(MeshDropFont.mono(10.5)).foregroundStyle(muted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.vertical, 18)
    }

    private var muted: Color {
        scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45
    }
}
