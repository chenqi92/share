//
//  MeshDropComplicationBundle.swift
//  MeshDropWatchComplications  (watchOS Widget Extension target — 需用户在 Xcode 手动新建)
//
//  watchOS 现代表盘 complication 用 WidgetKit（不是老 ClockKit）。本 bundle 提供一个
//  显示"在线设备数"的 complication，支持 accessoryCircular / accessoryRectangular /
//  accessoryInline / accessoryCorner 多种 family。
//
//  ⚠️ 用户需在 Xcode 手动操作（命令行 swift build 不会编译此 target）：
//  1. 选中 watchOS app，File ▸ New ▸ Target ▸ Widget Extension（platform = watchOS），
//     命名 "MeshDropWatchComplications"
//  2. 把本目录下两个 swift 文件加入该 target
//  3. 把 watch app 的 bridge/ComplicationSnapshot.swift 加入该 target 的 membership
//     （complication 进程要读同一份共享快照）
//  4. watch app target 和本 complication target 都启用同一 App Group
//     `group.com.welape.meshdrop`（Signing & Capabilities ▸ App Groups）
//  5. complication 默认 family 会出现在「自定义表盘 ▸ 复杂功能」里，用户手动添加到表盘
//

import WidgetKit
import SwiftUI

@main
struct MeshDropComplicationBundle: WidgetBundle {
    var body: some Widget {
        MeshDropStatusComplication()
    }
}
