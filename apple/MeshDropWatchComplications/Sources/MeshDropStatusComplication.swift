//
//  MeshDropStatusComplication.swift
//  MeshDropWatchComplications  (watchOS Widget Extension target)
//
//  "在线设备数" complication。数据来自 ComplicationStore（App Group 共享快照，由 watch app 写）。
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let deviceCount: Int
    let isOnline: Bool
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), deviceCount: 3, isOnline: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        let snap = ComplicationStore.read()
        completion(ComplicationEntry(date: Date(), deviceCount: snap.deviceCount, isOnline: snap.isOnline))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let snap = ComplicationStore.read()
        let entry = ComplicationEntry(date: Date(), deviceCount: snap.deviceCount, isOnline: snap.isOnline)
        // 静态展示：设备数靠 watch app 端 WidgetCenter.reloadAllTimelines() 主动刷新，
        // 这里给一个 15 分钟兜底刷新策略防止快照过期。
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct MeshDropStatusComplication: Widget {
    private let kind = "MeshDropStatusComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
        }
        .configurationDisplayName("MeshDrop 在线设备")
        .description("显示附近在线的 MeshDrop 设备数。")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner,
        ])
    }
}

// MARK: - 视图（按 family 分支）

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry

    var body: some View {
        switch family {
        case .accessoryCircular:   circular
        case .accessoryRectangular: rectangular
        case .accessoryInline:     inline
        case .accessoryCorner:     corner
        default:                   circular
        }
    }

    private var countText: String { entry.isOnline ? "\(entry.deviceCount)" : "—" }

    // 圆形：数字 + 角标。
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.isOnline
                      ? "dot.radiowaves.left.and.right" : "wifi.slash")
                    .font(.system(size: 11, weight: .semibold))
                Text(countText)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        }
        .widgetLabel {
            Text(entry.isOnline ? "MeshDrop" : "离线")
        }
    }

    // 矩形：图标 + 文案两行。
    private var rectangular: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.isOnline
                  ? "dot.radiowaves.left.and.right" : "wifi.slash")
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text("MeshDrop")
                    .font(.caption.weight(.semibold))
                Text(entry.isOnline ? "\(entry.deviceCount) 台设备在线" : "iPhone 不在身边")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    // 内联：单行文本（带前缀图标）。
    private var inline: some View {
        Label(
            entry.isOnline ? "MeshDrop · \(entry.deviceCount) 在线" : "MeshDrop · 离线",
            systemImage: entry.isOnline ? "dot.radiowaves.left.and.right" : "wifi.slash"
        )
    }

    // 角落：数字 + widgetLabel 弧形文案。
    private var corner: some View {
        Text(countText)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .widgetLabel {
                Text(entry.isOnline ? "MeshDrop \(entry.deviceCount)" : "MeshDrop 离线")
            }
    }
}
