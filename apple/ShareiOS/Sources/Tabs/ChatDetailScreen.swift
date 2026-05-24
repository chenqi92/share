import SwiftUI

struct ChatDetailScreen: View {
    let device: MockDevice
    @EnvironmentObject var state: AppState
    @Environment(\.colorScheme) private var scheme
    @State private var composerText: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    chatHeader
                    AsciiDivider("TODAY · 今天 · 14:08")
                    ForEach(Mock.chatWithMengxi) { m in
                        MsgBubble(m)
                    }
                    typingIndicator
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }

            composer
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Avatar(initials: device.initials, color: device.color, size: 26, online: device.isOnline)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(device.who)
                            .font(MeshDropFont.body(14, weight: .semibold))
                        Text("\(device.os) · \(device.rtt)ms · E2E")
                            .font(MeshDropFont.mono(9.5))
                            .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                IconBtn("ellipsis", size: 30, variant: .ghost)
            }
        }
    }

    private var chatHeader: some View {
        HStack(spacing: 8) {
            Chip("ONLINE", tone: .lime, mono: true, uppercased: true, icon: "circle.fill")
            Chip("E2E", tone: .outline, mono: true, uppercased: true)
            Spacer()
            Text("RTT \(device.rtt)ms")
                .font(MeshDropFont.mono(10))
                .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
        }
    }

    private var typingIndicator: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text("▸▸▸")
                    .font(MeshDropFont.mono(11, weight: .bold))
                    .foregroundStyle(MeshDropColor.flame)
                Text("\(device.who) 正在输入…")
                    .font(MeshDropFont.body(12))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.6) : MeshDropColor.ink60)
            }
            Spacer()
        }
        .padding(.leading, 4)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                IconBtn("paperclip", size: 32, variant: .ghost) { state.showSendSheet = true }
                IconBtn("photo", size: 32, variant: .ghost) { state.showSendSheet = true }
            }

            HStack {
                if composerText.isEmpty {
                    Text("想说点什么…")
                        .font(MeshDropFont.body(14))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.45) : MeshDropColor.ink45)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
            )
            .overlay(
                Capsule().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )

            IconBtn("arrow.up", size: 38, variant: .lime, shape: .circle)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            (scheme == .dark ? MeshDropColor.dink.opacity(0.92) : MeshDropColor.paper.opacity(0.92))
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line).frame(height: 0.5)
        }
    }
}
