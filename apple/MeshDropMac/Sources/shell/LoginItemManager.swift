import Foundation
import ServiceManagement
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "LoginItem")

/// 「登录时启动」的真实注册，基于 macOS 13+ 的 `SMAppService.mainApp`。
///
/// 注册 / 注销由系统持久化（写进登录项数据库），与 app 自己的 UserDefaults 设置分开。
/// 为避免两者漂移，UI 以 `isEnabled`（系统真实状态）为准回显，开关动作走 `setEnabled`。
enum LoginItemManager {
    /// 系统当前是否已把本 app 注册为登录项。`.enabled` 才算开。
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 注册 / 注销登录项。失败时记录日志并把错误抛给调用方决定如何回显。
    /// `.requiresApproval` 不视为失败——用户需在「系统设置 ▸ 通用 ▸ 登录项」里批准，
    /// 此时系统已记录意图，开关保持开启即可。
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            log.error("login item \(enabled ? "register" : "unregister") failed: \(error.localizedDescription)")
            return false
        }
    }
}
