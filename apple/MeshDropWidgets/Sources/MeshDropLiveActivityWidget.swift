//
//  MeshDropLiveActivityWidget.swift
//  MeshDropWidgets  (Widget Extension target — 由 project.yml 定义、xcodegen 生成)
//
//  传输进度 Live Activity 的 UI：锁屏卡片 + 灵动岛（compact / minimal / expanded）。
//  绑定 MeshDropKit 里共享的 MeshDropTransferActivityAttributes。
//
//  配色用品牌 token（见下方 BrandColor）：发送=flame、接收=sky、完成=lime、失败=error。
//  Widget target 的 source 与主 app 的 Theme/ 不重叠，故在此自带一份与
//  MeshDropColor 等值的简化调色板，绝不使用系统苹果蓝。
//

import WidgetKit
import SwiftUI
import MeshDropKit

/// Live Activity 专用品牌调色板。值与主 app 的 `MeshDropColor` 保持一致
/// （ink/paper/lime/flame/sky/error），供 widget target 独立编译用。
private enum BrandColor {
    static let lime  = Color(red: 0xDD/255, green: 0xF9/255, blue: 0x4B/255)
    static let flame = Color(red: 0xFF/255, green: 0x5A/255, blue: 0x2C/255)
    static let sky   = Color(red: 0x4D/255, green: 0xB8/255, blue: 0xFF/255)
    static let error = Color(red: 0xC4/255, green: 0x32/255, blue: 0x2B/255)
}

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
                        Text(context.attributes.isOutgoing ? MDW("liveActivity.expanded.send") : MDW("liveActivity.expanded.receive"))
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
        case .completed: return BrandColor.lime
        case .failed:    return BrandColor.error
        case .transferring: return ctx.attributes.isOutgoing ? BrandColor.flame : BrandColor.sky
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
        case .completed: return MDW("liveActivity.completed")
        case .failed:    return MDW("liveActivity.failed")
        case .transferring:
            if let bps = ctx.state.bytesPerSec, bps > 1 {
                return ByteCountFormatter.string(fromByteCount: Int64(bps), countStyle: .file) + "/s"
            }
            return MDW("liveActivity.transferring")
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
        case .completed: return BrandColor.lime
        case .failed:    return BrandColor.error
        case .transferring: return context.attributes.isOutgoing ? BrandColor.flame : BrandColor.sky
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
        case .completed: return context.attributes.isOutgoing ? MDW("liveActivity.headline.sent", who) : MDW("liveActivity.headline.received", who)
        case .failed:    return MDW("liveActivity.headline.failed", who)
        case .transferring: return context.attributes.isOutgoing ? MDW("liveActivity.headline.sending", who) : MDW("liveActivity.headline.receiving", who)
        }
    }
}
#endif
