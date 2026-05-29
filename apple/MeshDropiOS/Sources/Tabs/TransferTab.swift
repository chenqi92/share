import SwiftUI
import MeshDropKit
import QuickLook

struct TransferTab: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme
    /// QuickLook 预览的本地文件；非空时弹出系统预览。
    @State private var previewURL: URL?

    private var transfers: [MockTransfer] {
        engine.history.compactMap { h in
            h.displayTransfer(metrics: engine.transferMetrics[h.id])
        }
    }

    private var active: [MockTransfer]   { transfers.filter { $0.state == .transferring } }
    private var queued: [MockTransfer]   { transfers.filter { $0.state == .queued } }
    private var done: [MockTransfer]     { transfers.filter { $0.state == .done } }
    private var failed: [MockTransfer]   { transfers.filter { $0.state == .failed } }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if transfers.isEmpty {
                        emptyCard
                    } else {
                        if !active.isEmpty {
                            AsciiDivider("ACTIVE · 进行中 · \(active.count)")
                            ForEach(active) { item in
                                TransferRow(item, onCancel: { cancel(item) })
                            }
                        }
                        if !queued.isEmpty {
                            AsciiDivider("QUEUED · 等待 · \(queued.count)")
                            ForEach(queued) { TransferRow($0) }
                        }
                        if !done.isEmpty {
                            AsciiDivider("COMPLETED · 完成 · \(done.count)")
                            ForEach(done) { item in
                                TransferRow(item, onOpen: openClosure(for: item))
                            }
                        }
                        if !failed.isEmpty {
                            AsciiDivider("FAILED · 失败 · \(failed.count)")
                            ForEach(failed) { item in
                                TransferRow(item, onRetry: retryClosure(for: item))
                            }
                        }
                    }
                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { MeshDropLockup(size: 17) }
            ToolbarItem(placement: .topBarTrailing) {
                IconBtn("arrow.up.arrow.down", size: 30, variant: .ghost)
            }
        }
        .quickLookPreview($previewURL)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("传输")
                .font(MeshDropFont.display(28, weight: .bold))
            Text("Transfers.")
                .font(MeshDropFont.display(18, weight: .semibold))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink60)
        }
    }

    private func cancel(_ item: MockTransfer) {
        guard let id = UUID(uuidString: item.id) else { return }
        engine.cancelTransfer(id)
    }

    /// 仅对 outgoing 的失败项给重试闭包；URL 失效（外置盘断开等）时 retryTransfer 返回 false。
    private func retryClosure(for item: MockTransfer) -> (() -> Void)? {
        guard item.direction == .outgoing,
              let id = UUID(uuidString: item.id) else { return nil }
        return { [engine] in engine.retryTransfer(id) }
    }

    /// 仅对已接收完成的文件给打开闭包：按 history.id 查回落盘 URL，点了用 QuickLook 预览。
    private func openClosure(for item: MockTransfer) -> (() -> Void)? {
        guard item.direction == .incoming,
              let id = UUID(uuidString: item.id),
              let entry = engine.history.first(where: { $0.id == id }),
              case .file(_, _, let url) = entry.kind,
              let fileURL = url,
              FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return { previewURL = fileURL }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Text("没有传输任务")
                .font(MeshDropFont.body(14, weight: .semibold))
            Text("发送或接收文件后会出现在这里")
                .font(MeshDropFont.mono(10.5))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
    }
}
