import SwiftUI

struct OnboardingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var page: Int = 0

    private let pages: [(String, String, String, String)] = [
        ("dot.radiowaves.left.and.right", "雷达式发现",
         "Discovery.", "同一 Wi-Fi 下，设备 1 秒内互相 ping 到。"),
        ("hand.draw", "拖即发送",
         "Drag to send.", "把文件 / 照片 / 文字直接拖到设备上即可发送。"),
        ("lock.shield", "端到端加密",
         "E2E encryption.", "X25519 + ChaCha20-Poly1305，不经过云端。"),
    ]

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    MeshDropLockup(size: 22)
                    Spacer()
                    Button("跳过") { dismiss() }
                        .font(MeshDropFont.body(13, weight: .medium))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.6) : MeshDropColor.ink60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                TabView(selection: $page) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        slide(pages[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                indicators

                Button {
                    if page < pages.count - 1 { page += 1 } else { dismiss() }
                } label: {
                    Text(page < pages.count - 1 ? "下一步" : "开始使用")
                        .font(MeshDropFont.body(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(MeshDropColor.lime))
                        .foregroundStyle(MeshDropColor.ink)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
    }

    private func slide(_ tuple: (String, String, String, String)) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 10)
            HStack {
                Spacer()
                ZStack {
                    Circle().fill(MeshDropColor.lime.opacity(0.18)).frame(width: 200, height: 200)
                    Image(systemName: tuple.0)
                        .font(.system(size: 60, weight: .medium))
                        .foregroundStyle(scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink)
                }
                Spacer()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(tuple.1).font(MeshDropFont.display(28, weight: .bold))
                Text(tuple.2).font(MeshDropFont.display(20, weight: .semibold))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                Text(tuple.3).font(MeshDropFont.body(14))
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            Spacer()
        }
    }

    private var indicators: some View {
        HStack(spacing: 6) {
            ForEach(0..<pages.count, id: \.self) { i in
                Capsule()
                    .fill(page == i ? MeshDropColor.lime : (scheme == .dark ? Color.white.opacity(0.18) : MeshDropColor.ink12))
                    .frame(width: page == i ? 18 : 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
