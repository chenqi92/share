import Foundation
import WidgetKit

/// Complication（表盘）与 watch app 之间共享的轻量状态快照。
///
/// Complication 跑在独立的 Widget Extension 进程里，读不到 [WatchEngineProxy] 的内存状态，
/// 所以 watch app 把"在线设备数 + 是否在线"写进 **App Group 共享 UserDefaults**，
/// complication 的 TimelineProvider 从同一处读。
///
/// ⚠️ 需要用户在 Xcode 配置：watch app target 和 watch complication 的 Widget Extension target
/// 都启用同一个 App Group（建议 `group.com.welape.meshdrop`），并把本文件加入两个 target 的
/// membership。App Group 未配置时回退到标准 UserDefaults（同进程可用，跨进程失效但不崩）。
struct ComplicationSnapshot: Codable, Equatable {
    var deviceCount: Int
    var isOnline: Bool
    var updatedAt: Date

    static let empty = ComplicationSnapshot(deviceCount: 0, isOnline: false, updatedAt: .distantPast)
}

enum ComplicationStore {
    static let appGroupID = "group.com.welape.meshdrop"
    private static let key = "meshdrop.complication.snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// watch app 在 devices / online 变化时写入，并请求系统刷新所有 complication 时间线。
    static func write(deviceCount: Int, isOnline: Bool) {
        let snap = ComplicationSnapshot(deviceCount: deviceCount, isOnline: isOnline, updatedAt: Date())
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: key)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// complication 进程读取最新快照。
    static func read() -> ComplicationSnapshot {
        guard let data = defaults.data(forKey: key),
              let snap = try? JSONDecoder().decode(ComplicationSnapshot.self, from: data) else {
            return .empty
        }
        return snap
    }
}
