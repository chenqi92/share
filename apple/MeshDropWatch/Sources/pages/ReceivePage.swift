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

    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                if isOffline {
                    offlineCard
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                } else if let offer {
                    offerCard(offer)
                } else {
                    emptyCard
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
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
            MonoTag(text: "E2E", tone: .ink)
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
