import SwiftUI

struct HistoryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    AsciiDivider("TODAY · 今天 · \(Mock.history.count) 件")
                    ForEach(Mock.history) { row($0) }
                    AsciiDivider("EARLIER · 早些时候")
                    emptyMore
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
        }
        .navigationTitle("历史 · History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
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
                    Text(h.dir == .outgoing ? "发送给 \(h.peer)" : "来自 \(h.peer)")
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
                if (h.count ?? 0) > 1 {
                    Text("\(h.count!)").font(MeshDropFont.mono(8.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill(MeshDropColor.flame))
                        .offset(x: 10, y: -14)
                }
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
            Text("\(h.count ?? 1) 张图片").font(MeshDropFont.body(12)).foregroundStyle(muted)
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

    private var emptyMore: some View {
        VStack(spacing: 6) {
            Text("空空如也").font(MeshDropFont.body(13))
                .foregroundStyle(muted)
            Text("超过 24 小时的历史会折叠到归档")
                .font(MeshDropFont.mono(10.5)).foregroundStyle(muted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(.vertical, 18)
    }

    private var muted: Color {
        scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45
    }
}
