import SwiftUI

/// Live Activity 静态预览（mock）：上半部分为锁屏样式，下半部分为 Dynamic Island compact。
/// 真 ActivityKit + Widget Extension target 留待下一轮接 backend 时实装。
struct LiveActivityMock: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                AsciiDivider("LOCK SCREEN · 锁屏")
                lockScreenCard

                AsciiDivider("DYNAMIC ISLAND · 灵动岛")
                dynamicIslandPreview

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .navigationTitle("实时活动 · Live Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("关闭") { dismiss() }
            }
        }
    }

    // MARK: - Lock screen card

    private var lockScreenCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(MeshDropColor.lime).frame(width: 36, height: 36)
                MeshDropMark(size: 22)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("传输中")
                        .font(MeshDropFont.body(13, weight: .semibold))
                    Text("· 给 孟茜")
                        .font(MeshDropFont.body(13))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.6) : MeshDropColor.ink60)
                }
                HStack(spacing: 6) {
                    Text("iOS-mocks-final.zip")
                        .font(MeshDropFont.mono(11))
                        .lineLimit(1)
                    Text("· 48.6 MB")
                        .font(MeshDropFont.mono(11))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(scheme == .dark ? Color.white.opacity(0.10) : MeshDropColor.ink12)
                            .frame(height: 4)
                        Capsule().fill(MeshDropColor.flame)
                            .frame(width: geo.size.width * 0.84, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)
            }
            VStack(alignment: .trailing, spacing: 2) {
                Text("84%")
                    .font(MeshDropFont.display(20, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(MeshDropColor.flame)
                Text("剩 1s")
                    .font(MeshDropFont.mono(10))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(scheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.07) : Color(red: 0.96, green: 0.96, blue: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.08), lineWidth: 0.7)
        )
    }

    // MARK: - Dynamic Island

    private var dynamicIslandPreview: some View {
        VStack(spacing: 14) {
            // Compact
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.black)
                    .frame(width: 240, height: 36)
                HStack {
                    HStack(spacing: 5) {
                        MeshDropMark(size: 14)
                            .colorScheme(.dark)
                        Text("84%")
                            .font(MeshDropFont.mono(11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 14)
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MeshDropColor.flame)
                    Text("1s")
                        .font(MeshDropFont.mono(10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.trailing, 14)
                }
                .frame(width: 240)
            }

            // Expanded
            HStack {
                ZStack {
                    Circle().fill(.black).frame(width: 44, height: 44)
                    MeshDropMark(size: 22).colorScheme(.dark)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MeshDrop · 传输中")
                        .font(MeshDropFont.body(13, weight: .semibold))
                    Text("iOS-mocks-final.zip · 8.4 MB/s")
                        .font(MeshDropFont.mono(10.5))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                }
                Spacer()
                Text("84%")
                    .font(MeshDropFont.display(20, weight: .bold))
                    .foregroundStyle(MeshDropColor.flame)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 0.5)
            )
        }
    }
}
