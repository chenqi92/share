//
//  MeshDropWidgetBundle.swift
//  MeshDropWidgets  (Widget Extension target — 由 project.yml 定义、xcodegen 生成)
//
//  这是 iOS Widget Extension 的入口。包含：
//  - 传输进度 Live Activity（ActivityConfiguration + 灵动岛）
//
//  target 配置现状（已落地，无需手动建）：
//  - MeshDropWidgets target 在 MeshDropiOS/project.yml 定义，xcodegen 生成 .xcodeproj 时自动产出
//  - target 依赖 MeshDropKit package，共享 MeshDropTransferActivityAttributes 类型
//  - 主 app Info.plist 已带 NSSupportsLiveActivities = true（见 project.yml）
//  - ActivityKit 已在主 app 侧 LiveActivityManager 接入（Activity.request/update/end）
//  - widget 配色用自带的 BrandColor 调色板（见 MeshDropLiveActivityWidget.swift），
//    与 MeshDropColor 等值，避免跨 target 引用 Theme/ 文件
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
