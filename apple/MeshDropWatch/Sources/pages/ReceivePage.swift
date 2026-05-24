import SwiftUI
import WatchKit

struct ReceivePage: View {
    let offer: MockFileOffer
    var onAccept: () -> Void = {}
    var onReject: () -> Void = {}

    @State private var accepted: Bool = false

    var body: some View {
        ZStack {
            MD.dink.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
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

                    actionRow
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
        }
        .alert("已接收 ✓", isPresented: $accepted) {
            Button("好", role: .cancel) {}
        }
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

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                WKInterfaceDevice.current().play(.failure)
                onReject()
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
                accepted = true
                onAccept()
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

    private func shortInitials(_ s: String) -> String {
        if s.isEmpty { return "?" }
        return String(s.prefix(1))
    }
}

#Preview {
    ReceivePage(offer: Mock.pendingOffer)
}
