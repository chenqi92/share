import Foundation

/// MeshDropKit 内部用户可见文案的本地化入口。
///
/// 为什么集中在这里：kit 是 SwiftPM 库，运行时资源在 `.module` bundle 里，
/// 调用点散落在 ShareEngine / IncomingNotifier 等处。集中成一组 static 方法，
/// 既能统一指向 `Localizable.xcstrings`（点分 key 命名空间），又便于上层对照、
/// 避免每个调用点重复写 `bundle: .module`。
///
/// 约定：key 用点分命名空间（如 `notification.incoming.file`），带占位符的用
/// `String(format:)` 让各语言文件自行决定语序。
enum L10n {

    /// 不带参数：直接按 key 取本地化串。
    static func t(_ key: String.LocalizationValue, _ table: String = "Localizable") -> String {
        String(localized: key, table: table, bundle: .module)
    }

    // MARK: - 入站通知（IncomingNotifier）

    /// 收到对方发来的文件时的通知标题。`%@` = 对端显示名。
    static func notifIncomingFile(peer: String) -> String {
        String(format: t("notification.incoming.file"), peer)
    }

    /// 收到对方推送剪贴板时的通知标题。`%@` = 对端显示名。
    static func notifClipboard(peer: String) -> String {
        String(format: t("notification.incoming.clipboard"), peer)
    }

    /// 收到对方发文件请求（offer）时的通知标题。`%@` = 对端显示名。
    static func notifFileOffer(peer: String) -> String {
        String(format: t("notification.incoming.offer"), peer)
    }

    // MARK: - 传输失败状态（TransferStatus.failed 文案）

    /// 读取本地源文件失败。`%@` = 系统错误描述。
    static func failReadFile(_ detail: String) -> String {
        String(format: t("transfer.fail.readFile"), detail)
    }

    /// 对方拒收。`%@` = 对端给出的原因（协议常量，保持原文）。
    static func failPeerRejected(_ reason: String) -> String {
        String(format: t("transfer.fail.peerRejected"), reason)
    }

    /// 协议错误：单个分块超过上限。
    static var failChunkTooLarge: String { t("transfer.fail.chunkTooLarge") }

    /// 文件校验（哈希）不通过。
    static var failChecksum: String { t("transfer.fail.checksum") }

    /// 连接中断、但已记录断点可续传。
    static var failDisconnectedResumable: String { t("transfer.fail.disconnectedResumable") }

    /// 连接中断（不可续传）。
    static var failDisconnected: String { t("transfer.fail.disconnected") }

    /// 无法连接到对端（建连 / 握手超时，从未成功握手）。
    static var failCouldNotConnect: String { t("transfer.fail.couldNotConnect") }

    // MARK: - 发现层错误

    /// 本地网络不可用（最常见：用户未授予本地网络权限）。
    static var discoveryUnavailable: String { t("discovery.unavailable") }
}
