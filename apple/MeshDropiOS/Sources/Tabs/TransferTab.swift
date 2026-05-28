import SwiftUI
import MeshDropKit

struct TransferTab: View {
    @EnvironmentObject var state: AppState
    @EnvironmentObject var engine: ShareEngine
    @Environment(\.colorScheme) private var scheme

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
                            ForEach(active) { TransferRow($0) }
                        }
                        if !queued.isEmpty {
                            AsciiDivider("QUEUED · 等待 · \(queued.count)")
                            ForEach(queued) { TransferRow($0) }
                        }
                        if !done.isEmpty {
                            AsciiDivider("COMPLETED · 完成 · \(done.count)")
                            ForEach(done) { TransferRow($0) }
                        }
                        if !failed.isEmpty {
                            AsciiDivider("FAILED · 失败 · \(failed.count)")
                            ForEach(failed) { TransferRow($0) }
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
