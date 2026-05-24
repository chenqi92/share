import SwiftUI

struct TransferTab: View {
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    summaryCard
                    filterChips
                    AsciiDivider("ACTIVE · 进行中 · 3")
                    ForEach(Mock.transfers.filter { $0.state == .transferring }) { TransferRow($0) }
                    AsciiDivider("QUEUED · 等待")
                    ForEach(Mock.transfers.filter { $0.state == .queued }) { TransferRow($0) }
                    AsciiDivider("COMPLETED · 完成 · 2")
                    ForEach(Mock.transfers.filter { $0.state == .done }) { TransferRow($0) }
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

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 18) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("UPLOAD ↑")
                        .font(MeshDropFont.mono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(MeshDropColor.flame)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("8.4").font(MeshDropFont.display(28, weight: .bold)).monospacedDigit()
                        Text("MB/s").font(MeshDropFont.mono(11)).foregroundStyle(MeshDropColor.flame.opacity(0.8))
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("DOWNLOAD ↓")
                        .font(MeshDropFont.mono(10, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(MeshDropColor.sky)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("11.7").font(MeshDropFont.display(28, weight: .bold)).monospacedDigit()
                        Text("MB/s").font(MeshDropFont.mono(11)).foregroundStyle(MeshDropColor.sky.opacity(0.8))
                    }
                }
                Spacer()
            }
            // 双向条形
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<Mock.uploadBars.count, id: \.self) { i in
                    VStack(spacing: 1) {
                        Rectangle().fill(MeshDropColor.flame)
                            .frame(width: 8, height: CGFloat(Mock.uploadBars[i]) * 3)
                        Rectangle().fill(MeshDropColor.sky)
                            .frame(width: 8, height: CGFloat(Mock.downloadBars[i]) * 3)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
        )
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            Chip("全部", tone: .lime, mono: false)
            Chip("发送", tone: .outline, mono: false)
            Chip("接收", tone: .outline, mono: false)
            Chip("失败", tone: .outline, mono: false)
            Spacer()
        }
    }
}
