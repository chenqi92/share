//
//  MeshDropWidgetBundle.swift
//  MeshDropWidgets  (Widget Extension target — 需用户在 Xcode 手动新建)
//
//  这是 iOS Widget Extension 的入口。包含：
//  - 传输进度 Live Activity（ActivityConfiguration + 灵动岛）
//
//  ⚠️ 用户需在 Xcode 手动操作（命令行 swift build 不会编译此 target）：
//  1. File ▸ New ▸ Target ▸ Widget Extension，命名 "MeshDropWidgets"
//     - 勾选 "Include Live Activity"
//  2. 把本目录下的 MeshDropWidgetBundle.swift / MeshDropLiveActivityWidget.swift 加入该 target
//  3. 把 MeshDropKit 里的 LiveActivityAttributes.swift 同时加入该 target 的 membership
//     （或让 widget target 依赖 MeshDropKit framework / 引用同一文件），保证两端是同一份
//     MeshDropTransferActivityAttributes 类型。
//  4. 主 app target 的 Info.plist 加 `NSSupportsLiveActivities = YES`
//  5. 若 widget UI 用到 MeshDropColor / MeshDropFont，需把对应主题文件也加入 widget target
//     的 membership，或在 widget 内自带一份简化配色（本文件已用系统色，避免强耦合）。
//

import WidgetKit
import SwiftUI

@main
struct MeshDropWidgetBundle: WidgetBundle {
    var body: some Widget {
        // iOS 16.1+ 才有 Live Activity。
        if #available(iOS 16.1, *) {
            MeshDropLiveActivityWidget()
        }
        // 如需主屏 / 锁屏静态 widget，可在此追加更多 Widget。
    }
}
