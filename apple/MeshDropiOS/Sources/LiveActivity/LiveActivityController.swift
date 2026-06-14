import SwiftUI
import MeshDropKit

/// Live Activity 的**页内预览组件**（不是 ActivityKit 控制器）。
///
/// 真 ActivityKit 接入在 `LiveActivityManager`，Widget Extension（MeshDropWidgets）由
/// project.yml 定义、xcodegen 生成。本视图只在 app 内展示一份样式预览：
/// - 读取 `engine.history` 里最新的 `.transferring` 文件项渲染锁屏卡片 / 灵动岛样例；没有时显示占位。
/// - 与真 widget 的配色一致（发送 flame / 接收 sky / 完成 lime / 失败 error）。
struct LiveActivityController: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject var engine: ShareEngine

    private var activeTransfer: HistoryItem? {
        engine.history.first(where: {
            if case .transferring = $0.status, case .file = $0.kind { return true }
            return false
        })
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? MeshDropColor.dink : MeshDropColor.paper).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                AsciiDivider(MD("liveActivity.lockScreen.section"))
                if let item = activeTransfer { lockScreenCard(item) } else { idleCard }

                AsciiDivider(MD("liveActivity.dynamicIsland.section"))
                if let item = activeTransfer { dynamicIslandPreview(item) } else { idleIsland }

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
        }
        .navigationTitle(MD("liveActivity.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(MD("common.close")) { dismiss() }
            }
        }
    }

    // MARK: - Lock screen card

    private func lockScreenCard(_ item: HistoryItem) -> some View {
        let (name, size, percent) = display(item)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(MeshDropColor.lime).frame(width: 36, height: 36)
                MeshDropMark(size: 22)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.direction == .outgoing ? MD("liveActivity.transferring") : MD("liveActivity.receiving"))
                        .font(MeshDropFont.body(13, weight: .semibold))
                    Text("· \(item.direction == .outgoing ? MD("liveActivity.to") : MD("liveActivity.from")) \(item.peer.name)")
                        .font(MeshDropFont.body(13))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.6) : MeshDropColor.ink60)
                }
                HStack(spacing: 6) {
                    Text(name)
                        .font(MeshDropFont.mono(11))
                        .lineLimit(1)
                    Text("· \(size)")
                        .font(MeshDropFont.mono(11))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(scheme == .dark ? Color.white.opacity(0.10) : MeshDropColor.ink12)
                            .frame(height: 4)
                        Capsule().fill(item.direction == .outgoing ? MeshDropColor.flame : MeshDropColor.sky)
                            .frame(width: geo.size.width * percent, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.top, 2)
            }
            Text("\(Int(percent * 100))%")
                .font(MeshDropFont.display(20, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(item.direction == .outgoing ? MeshDropColor.flame : MeshDropColor.sky)
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

    private var idleCard: some View {
        HStack {
            ZStack {
                Circle().fill(scheme == .dark ? MeshDropColor.dink2 : MeshDropColor.card)
                    .frame(width: 36, height: 36)
                MeshDropMark(size: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(MD("liveActivity.idle.title")).font(MeshDropFont.body(13, weight: .semibold))
                Text(MD("liveActivity.idle.subtitle"))
                    .font(MeshDropFont.mono(10.5))
                    .foregroundStyle(scheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45)
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(scheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.07) : Color(red: 0.96, green: 0.96, blue: 0.97))
        )
    }

    // MARK: - Dynamic Island

    private func dynamicIslandPreview(_ item: HistoryItem) -> some View {
        let (name, _, percent) = display(item)
        return VStack(spacing: 14) {
            // Compact
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.black)
                    .frame(width: 240, height: 36)
                HStack {
                    HStack(spacing: 5) {
                        MeshDropMark(size: 14).colorScheme(.dark)
                        Text("\(Int(percent * 100))%")
                            .font(MeshDropFont.mono(11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.leading, 14)
                    Spacer()
                    Image(systemName: item.direction == .outgoing ? "arrow.up" : "arrow.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(item.direction == .outgoing ? MeshDropColor.flame : MeshDropColor.sky)
                    Text(item.peer.name.prefix(4))
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
                    Text("MeshDrop · \(item.direction == .outgoing ? MD("liveActivity.transferring") : MD("liveActivity.receiving"))")
                        .font(MeshDropFont.body(13, weight: .semibold))
                    Text(name)
                        .font(MeshDropFont.mono(10.5))
                        .foregroundStyle(scheme == .dark ? Color.white.opacity(0.55) : MeshDropColor.ink60)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(Int(percent * 100))%")
                    .font(MeshDropFont.display(20, weight: .bold))
                    .foregroundStyle(item.direction == .outgoing ? MeshDropColor.flame : MeshDropColor.sky)
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

    private var idleIsland: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.black)
                    .frame(width: 200, height: 36)
                Text("MeshDrop").font(MeshDropFont.mono(11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func display(_ item: HistoryItem) -> (String, String, Double) {
        guard case .file(let name, let size, _) = item.kind else { return (item.peer.name, "—", 0) }
        let percent = item.status.progressFraction
        let sizeStr = HistoryItem.byteFormatter.string(fromByteCount: Int64(size))
        return (name, sizeStr, percent)
    }
}

/// 兼容 PadRoot / PhoneRoot 中保留的 `LiveActivityMock` 引用。
typealias LiveActivityMock = LiveActivityController
