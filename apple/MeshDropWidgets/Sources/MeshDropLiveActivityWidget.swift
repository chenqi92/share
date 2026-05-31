//
//  MeshDropLiveActivityWidget.swift
//  MeshDropWidgets  (Widget Extension target — 需用户在 Xcode 手动新建)
//
//  传输进度 Live Activity 的 UI：锁屏卡片 + 灵动岛（compact / minimal / expanded）。
//  绑定 MeshDropKit 里共享的 MeshDropTransferActivityAttributes。
//
//  本文件用系统色（不依赖主 app 的 MeshDropColor / MeshDropFont），以便加入 widget target
//  后能独立编译。如需贴近品牌色，把主题文件加入 widget target membership 后替换即可。
//

import WidgetKit
import SwiftUI
import MeshDropKit

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct MeshDropLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeshDropTransferActivityAttributes.self) { context in
            // 锁屏 / 横幅
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.isOutgoing ? "发送" : "接收")
                            .font(.caption2)
                    } icon: {
                        Image(systemName: context.attributes.isOutgoing
                              ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(accent(context))
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(percent(context))%")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(accent(context))
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.fileName)
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        ProgressView(value: fraction(context))
                            .tint(accent(context))
                        HStack {
                            Text(context.attributes.peerName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(subtitle(context))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: context.attributes.isOutgoing ? "arrow.up" : "arrow.down")
                    .foregroundStyle(accent(context))
            } compactTrailing: {
                Text("\(percent(context))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(accent(context))
            } minimal: {
                Image(systemName: phaseGlyph(context))
                    .foregroundStyle(accent(context))
            }
            .keylineTint(accent(context))
        }
    }

    // MARK: - 派生值

    private func fraction(_ ctx: ActivityViewContext<MeshDropTransferActivityAttributes>) -> Double {
        let total = ctx.attributes.totalBytes
        guard total > 0 else { return ctx.state.phase == .completed ? 1 : 0 }
        return min(1.0, Double(ctx.state.bytesDone) / Double(total))
    }

    private func percent(_ ctx: ActivityViewContext<MeshDropTransferActivityAttributes>) -> Int {
        Int(fraction(ctx) * 100)
    }

    private func accent(_ ctx: ActivityViewContext<MeshDropTransferActivityAttributes>) -> Color {
        switch ctx.state.phase {
        case .completed: return .green
        case .failed:    return .red
        case .transferring: return ctx.attributes.isOutgoing ? .orange : .blue
        }
    }

    private func phaseGlyph(_ ctx: ActivityViewContext<MeshDropTransferActivityAttributes>) -> String {
        switch ctx.state.phase {
        case .completed: return "checkmark.circle.fill"
        case .failed:    return "xmark.circle.fill"
        case .transferring: return ctx.attributes.isOutgoing ? "arrow.up" : "arrow.down"
        }
    }

    private func subtitle(_ ctx: ActivityViewContext<MeshDropTransferActivityAttributes>) -> String {
        switch ctx.state.phase {
        case .completed: return "已完成"
        case .failed:    return "失败"
        case .transferring:
            if let bps = ctx.state.bytesPerSec, bps > 1 {
                return ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file) + "/s"
            }
            return "传输中"
        }
    }
}

// MARK: - 锁屏卡片

@available(iOS 16.1, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<MeshDropTransferActivityAttributes>

    private var fraction: Double {
        let total = context.attributes.totalBytes
        guard total > 0 else { return context.state.phase == .completed ? 1 : 0 }
        return min(1.0, Double(context.state.bytesDone) / Double(total))
    }

    private var accent: Color {
        switch context.state.phase {
        case .completed: return .green
        case .failed:    return .red
        case .transferring: return context.attributes.isOutgoing ? .orange : .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.25)).frame(width: 40, height: 40)
                Image(systemName: context.attributes.isOutgoing ? "arrow.up" : "arrow.down")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(Int(fraction * 100))%")
                        .font(.subheadline.bold().monospacedDigit())
                        .foregroundStyle(accent)
                }
                Text(context.attributes.fileName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.7))
                ProgressView(value: fraction)
                    .tint(accent)
            }
        }
        .padding(14)
    }

    private var headline: String {
        let who = context.attributes.peerName
        switch context.state.phase {
        case .completed: return context.attributes.isOutgoing ? "已发送给 \(who)" : "已接收自 \(who)"
        case .failed:    return "传输失败 · \(who)"
        case .transferring: return context.attributes.isOutgoing ? "正在发送给 \(who)" : "正在接收自 \(who)"
        }
    }
}
#endif
