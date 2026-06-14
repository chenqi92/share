import SwiftUI
import WatchKit

struct ReceivePage: View {
    @ObservedObject var proxy: WatchEngineProxy = .shared

    /// Preview / 调试用：直接喂 VM 跳过 proxy。
    var debugOffer: WatchOfferVM? = nil

    @State private var accepted: Bool = false
    @State private var rejected: Bool = false
    @State private var commandError: String?

    private var offer: WatchOfferVM? {
        if let debugOffer { return debugOffer }
        return proxy.pendingOffers.first.map { WatchOfferVM(bridge: $0) }
    }

    private var isOffline: Bool { debugOffer == nil && !proxy.isOnline }

    /// 真实收件箱（iPhone 中转来的入站内容）。debug 模式下为空。
    private var inboxItems: [BridgeInboxItem] { debugOffer == nil ? proxy.inbox : [] }

    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    // 1. 待审 offer（接受/拒绝）。
                    if let offer { offerCard(offer) }

                    // 2. 已接收内容（真实收件箱）。
                    if !inboxItems.isEmpty {
                        inboxSection
                    }

                    // 3. 都没有时：离线 / 空态。
                    if offer == nil && inboxItems.isEmpty {
                        if isOffline {
                            offlineCard.padding(.horizontal, 8).padding(.top, 6)
                        } else {
                            emptyCard.padding(.horizontal, 8).padding(.top, 6)
                        }
                    }
                }
            }
        }
        .alert("已接收 ✓", isPresented: $accepted) { Button("好", role: .cancel) {} }
        .alert("已拒绝 ×", isPresented: $rejected) { Button("好", role: .cancel) {} }
        .alert(
            "出错",
            isPresented: Binding(get: { commandError != nil },
                                 set: { if !$0 { commandError = nil } })
        ) {
            Button("好", role: .cancel) { commandError = nil }
        } message: {
            Text(commandError ?? "")
        }
    }

    private func offerCard(_ offer: WatchOfferVM) -> some View {
        VStack(spacing: 3) {
            headerLabel

            HStack(spacing: 8) {
                Avatar(
                    initials: shortInitials(offer.peer),
                    color: Color(red: 1.00, green: 0.70, blue: 0.63),
                    size: 36,
                    ring: true,
                    ringColor: MD.lime
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(offer.peer)
                        .font(MDFont.display(16, weight: .bold))
                        .tracking(-0.4)
                        .foregroundColor(MD.dpaper)
                    Text(offer.deviceName)
                        .font(MDFont.mono(9, weight: .medium))
                        .tracking(0.6)
                        .foregroundColor(MD.dim)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 2)

            FileChipMini(name: offer.fileName, size: offer.fileSize, ext: offer.ext)
                .padding(.top, 2)

            if !offer.note.isEmpty {
                HStack(alignment: .top, spacing: 3) {
                    Text("✱")
                        .font(MDFont.mono(9, weight: .bold))
                        .foregroundColor(MD.lime)
                    Text(offer.note)
                        .font(MDFont.body(10, weight: .regular))
                        .foregroundColor(MD.muted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(.horizontal, 2)
            }

            actionRow(offer: offer)
                .padding(.top, 3)

            Text("⌃ 双击侧键也行")
                .font(MDFont.mono(10, weight: .medium))
                .tracking(0.6)
                .foregroundColor(MD.dim)
                .padding(.top, 1)
                .padding(.bottom, 2)
        }
        .padding(.horizontal, 8)
        .padding(.top, 0)
    }

    private var headerLabel: some View {
        HStack(spacing: 3) {
            Circle().fill(MD.lime).frame(width: 5, height: 5)
            Text("来自 · FROM")
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.lime)
            Spacer()
            MonoTag(text: "LAN", tone: .ink)
        }
    }

    private var offlineCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("OFFLINE")
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.dim)
            Text("iPhone 不在身边")
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text("接收功能暂不可用")
                .font(MDFont.body(11, weight: .regular))
                .foregroundColor(MD.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MD.dink2))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MD.dline, lineWidth: 0.5))
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("收件箱 · INBOX")
                .font(MDFont.mono(10, weight: .bold))
                .tracking(1.4)
                .foregroundColor(MD.dim)
            Text("没有新文件")
                .font(MDFont.display(14, weight: .semibold))
                .foregroundColor(MD.dpaper)
            Text("有人发来时会自动弹出")
                .font(MDFont.body(11, weight: .regular))
                .foregroundColor(MD.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MD.dink2))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MD.dline, lineWidth: 0.5))
    }

    // MARK: - 收件箱（真实接收）

    private var inboxSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                Circle().fill(MD.lime).frame(width: 5, height: 5)
                Text("收件箱 · INBOX")
                    .font(MDFont.mono(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundColor(MD.lime)
                Spacer()
            }
            .padding(.horizontal, 4)

            ForEach(inboxItems) { item in
                inboxRow(item)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func inboxRow(_ item: BridgeInboxItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.peerName)
                    .font(MDFont.mono(9, weight: .bold))
                    .tracking(0.6)
                    .foregroundColor(MD.dim)
                    .lineLimit(1)
                Spacer()
                Button {
                    WKInterfaceDevice.current().play(.click)
                    proxy.removeInboxItem(item.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(MD.dim)
                }
                .buttonStyle(.plain)
            }

            if item.isText {
                Text(item.text ?? "")
                    .font(MDFont.body(13, weight: .regular))
                    .foregroundColor(MD.dpaper)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                FileChipMini(
                    name: item.fileName ?? "文件",
                    size: byteString(item.sizeBytes),
                    ext: (item.fileName as NSString?)?.pathExtension ?? ""
                )
                Text(item.fileAvailable ? "已存到 iPhone · 表上可预览" : "正在从 iPhone 传输…")
                    .font(MDFont.mono(8, weight: .medium))
                    .foregroundColor(item.fileAvailable ? MD.lime : MD.dim)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MD.dink2))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MD.dline, lineWidth: 0.5))
    }

    private func byteString(_ n: UInt64?) -> String {
        guard let n else { return "—" }
        let units = ["B", "KB", "MB", "GB"]
        var v = Double(n)
        var idx = 0
        while v >= 1024 && idx < units.count - 1 { v /= 1024; idx += 1 }
        return idx == 0 ? "\(Int(v)) \(units[idx])" : String(format: "%.1f %@", v, units[idx])
    }

    private func actionRow(offer: WatchOfferVM) -> some View {
        HStack(spacing: 8) {
            Button {
                WKInterfaceDevice.current().play(.failure)
                Task { await reject(offerId: offer.id) }
            } label: {
                ZStack {
                    Circle().fill(MD.dink3)
                        .overlay(Circle().stroke(MD.dline, lineWidth: 0.5))
                    Text("×")
                        .font(MDFont.display(20, weight: .bold))
                        .foregroundColor(MD.dpaper)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Button {
                WKInterfaceDevice.current().play(.success)
                Task { await accept(offerId: offer.id) }
            } label: {
                HStack(spacing: 3) {
                    Text("接收")
                        .font(MDFont.display(16, weight: .bold))
                        .foregroundColor(MD.dink)
                    Text("✓")
                        .font(MDFont.display(16, weight: .bold))
                        .foregroundColor(MD.dink)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(MD.lime))
            }
            .buttonStyle(.plain)
        }
    }

    private func accept(offerId: String) async {
        guard debugOffer == nil else { accepted = true; return }
        do {
            try await proxy.acceptOffer(offerId)
            accepted = true
        } catch {
            commandError = error.localizedDescription
        }
    }

    private func reject(offerId: String) async {
        guard debugOffer == nil else { rejected = true; return }
        do {
            try await proxy.rejectOffer(offerId)
            rejected = true
        } catch {
            commandError = error.localizedDescription
        }
    }

    private func shortInitials(_ s: String) -> String {
        if s.isEmpty { return "?" }
        return String(s.prefix(1))
    }
}

#Preview {
    ReceivePage(debugOffer: WatchOfferVM(mock: Mock.pendingOffer))
}
