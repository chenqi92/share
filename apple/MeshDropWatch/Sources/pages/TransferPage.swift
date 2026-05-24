import SwiftUI

struct TransferPage: View {
    let transfer: MockTransfer

    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    header

                    progressBlock

                    HStack(spacing: 4) {
                        directionArrow
                        Text("→")
                            .font(MDFont.mono(11, weight: .bold))
                            .foregroundColor(MD.dim)
                        Text(transfer.peer)
                            .font(MDFont.display(13, weight: .semibold))
                            .foregroundColor(MD.dpaper)
                        Spacer()
                    }

                    FileChipMini(name: transfer.name, size: transfer.size, ext: transfer.ext, progress: transfer.progress)

                    statRow

                    Text("传输由手机继续 · 手表只显示进度")
                        .font(MDFont.mono(10, weight: .medium))
                        .tracking(0.8)
                        .foregroundColor(MD.dim)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Circle().fill(stateColor).frame(width: 6, height: 6)
            Text(stateLabel)
                .font(MDFont.mono(11, weight: .bold))
                .tracking(1.6)
                .foregroundColor(stateColor)
            Spacer()
            MeshDropMark(size: 12)
        }
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(transfer.progress)")
                    .font(MDFont.display(30, weight: .bold))
                    .tracking(-1.0)
                    .foregroundColor(MD.dpaper)
                Text("%")
                    .font(MDFont.mono(13, weight: .medium))
                    .foregroundColor(MD.muted)
                Spacer()
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(MD.dline).frame(height: 4)
                    RoundedRectangle(cornerRadius: 2).fill(stateColor)
                        .frame(width: g.size.width * CGFloat(transfer.progress) / 100.0, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private var statRow: some View {
        HStack(spacing: 10) {
            if let speed = transfer.speed {
                statItem(label: "速度", value: speed, color: stateColor)
            }
            if let eta = transfer.eta {
                statItem(label: "剩余", value: eta, color: MD.dpaper)
            }
        }
    }

    private func statItem(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(MDFont.mono(9, weight: .bold))
                .tracking(1.2)
                .foregroundColor(MD.dim)
            Text(value)
                .font(MDFont.mono(13, weight: .bold))
                .foregroundColor(color)
        }
    }

    private var directionArrow: some View {
        Text(transfer.direction == .outgoing ? "↑" : "↓")
            .font(MDFont.mono(12, weight: .bold))
            .foregroundColor(transfer.direction == .outgoing ? MD.flame : MD.sky)
    }

    private var stateColor: Color {
        switch transfer.state {
        case .sending:   return MD.flame
        case .receiving: return MD.sky
        case .done:      return MD.limeDeep
        case .queued:    return MD.muted
        case .failed:    return MD.error
        }
    }

    private var stateLabel: String {
        switch transfer.state {
        case .sending:   return "SENDING ↑"
        case .receiving: return "RECEIVING ↓"
        case .done:      return "DONE ✓"
        case .queued:    return "QUEUED ·"
        case .failed:    return "FAILED ×"
        }
    }
}

#Preview {
    TransferPage(transfer: Mock.runningTransfer)
}
