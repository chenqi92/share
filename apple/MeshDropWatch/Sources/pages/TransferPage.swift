import SwiftUI

struct TransferPage: View {
    @ObservedObject var proxy: WatchEngineProxy = .shared

    /// Preview / 调试用：直接喂 VM 跳过 proxy。
    var debugTransfer: WatchTransferVM? = nil

    private var transfer: WatchTransferVM? {
        if let debugTransfer { return debugTransfer }
        guard let p = proxy.transfers.values.first else { return nil }
        return WatchTransferVM(bridge: p)
    }

    private var isOffline: Bool { debugTransfer == nil && !proxy.isOnline }

    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                if isOffline {
                    offlineCard
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                } else if let transfer {
                    contentCard(transfer)
                } else {
                    idleCard
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                }
            }
        }
    }

    private func contentCard(_ transfer: WatchTransferVM) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(transfer)

            progressBlock(transfer)

            HStack(spacing: 4) {
                directionArrow(transfer)
                Text("→")
                    .font(MDFont.mono(11, weight: .bold))
                    .foregroundColor(MD.dim)
                Text(transfer.peer.isEmpty ? "—" : transfer.peer)
                    .font(MDFont.display(13, weight: .semibold))
                    .foregroundColor(MD.dpaper)
                Spacer()
            }

            FileChipMini(name: transfer.name, size: transfer.size, ext: transfer.ext, progress: transfer.progress)

            statRow(transfer)

            Text(L10n.transferFooterHint)
                .font(MDFont.mono(10, weight: .medium))
                .tracking(0.8)
                .foregroundColor(MD.dim)
                .padding(.top, 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OFFLINE")
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.dim)
            Text(L10n.transferOfflineTitle)
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text(L10n.transferOfflineDetail)
                .font(MDFont.body(11, weight: .regular))
                .foregroundColor(MD.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MD.dink2))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MD.dline, lineWidth: 0.5))
    }

    private var idleCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.transferIdleTag)
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.dim)
            Text(L10n.transferIdleTitle)
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text(L10n.transferIdleDetail)
                .font(MDFont.body(11, weight: .regular))
                .foregroundColor(MD.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MD.dink2))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MD.dline, lineWidth: 0.5))
    }

    private func header(_ transfer: WatchTransferVM) -> some View {
        HStack(spacing: 6) {
            Circle().fill(stateColor(transfer)).frame(width: 6, height: 6)
            Text(stateLabel(transfer))
                .font(MDFont.mono(11, weight: .bold))
                .tracking(1.6)
                .foregroundColor(stateColor(transfer))
            Spacer()
            MeshDropMark(size: 12)
        }
    }

    private func progressBlock(_ transfer: WatchTransferVM) -> some View {
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
                    RoundedRectangle(cornerRadius: 2).fill(stateColor(transfer))
                        .frame(width: g.size.width * CGFloat(transfer.progress) / 100.0, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private func statRow(_ transfer: WatchTransferVM) -> some View {
        HStack(spacing: 10) {
            if let speed = transfer.speed {
                statItem(label: L10n.transferStatSpeed, value: speed, color: stateColor(transfer))
            }
            if let eta = transfer.eta {
                statItem(label: L10n.transferStatEta, value: eta, color: MD.dpaper)
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

    private func directionArrow(_ transfer: WatchTransferVM) -> some View {
        Text(transfer.direction == .outgoing ? "↑" : "↓")
            .font(MDFont.mono(12, weight: .bold))
            .foregroundColor(transfer.direction == .outgoing ? MD.flame : MD.sky)
    }

    private func stateColor(_ transfer: WatchTransferVM) -> Color {
        switch transfer.state {
        case .sending:   return MD.flame
        case .receiving: return MD.sky
        case .done:      return MD.limeDeep
        case .queued:    return MD.muted
        case .failed:    return MD.error
        }
    }

    private func stateLabel(_ transfer: WatchTransferVM) -> String {
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
    TransferPage(debugTransfer: WatchTransferVM(mock: Mock.runningTransfer))
}
