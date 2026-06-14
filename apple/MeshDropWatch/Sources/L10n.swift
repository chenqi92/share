import Foundation

/// 集中式本地化访问点：所有用户可见文案走 `String(localized:)`，
/// 由 `Localizable.xcstrings` 提供 zh-Hans（默认）/ en 两份翻译。
///
/// why：手表屏小、屏数固定，集中成静态常量便于静态核对 key 完整性（每个引用的 key
/// 都能在 catalog 两份里找到），也避免散落的裸字符串再次硬编码漏翻。
enum L10n {

    // MARK: 通用

    static let commonOK = String(localized: "common.ok")
    static let commonCancel = String(localized: "common.cancel")
    static let commonError = String(localized: "common.error")

    // MARK: Nearby（附近）

    static let nearbyTitle = String(localized: "nearby.title")
    static let nearbyTitleSuffix = String(localized: "nearby.title.suffix")
    static let nearbyHintCrown = String(localized: "nearby.hint.crown")
    static let nearbyHintOffline = String(localized: "nearby.hint.offline")
    static let nearbyOfflineTitle = String(localized: "nearby.offline.title")
    static let nearbyOfflineDetail = String(localized: "nearby.offline.detail")
    static let nearbyEmptyTag = String(localized: "nearby.empty.tag")
    static let nearbyEmptyTitle = String(localized: "nearby.empty.title")
    static let nearbyEmptyDetail = String(localized: "nearby.empty.detail")
    static let nearbyFooterHint = String(localized: "nearby.footer.hint")

    /// "多选 · N 台 · SELECTED"
    static func nearbySelectedCount(_ n: Int) -> String {
        String(localized: "nearby.selected.count \(n)")
    }
    /// "已发送 · SENT · <peer>"
    static func nearbySent(_ peer: String) -> String {
        String(localized: "nearby.sent \(peer)")
    }
    /// "发送失败 · <reason>"
    static func nearbySendFailed(_ reason: String) -> String {
        String(localized: "nearby.send.failed \(reason)")
    }

    // MARK: 发文本 sheet

    static let composerTo = String(localized: "composer.to")
    static let composerPlaceholder = String(localized: "composer.placeholder")
    static let composerSend = String(localized: "composer.send")
    static let composerCancel = String(localized: "composer.cancel")

    // MARK: Receive（接收）

    static let receiveFrom = String(localized: "receive.from")
    static let receiveSideHint = String(localized: "receive.side.hint")
    static let receiveAccept = String(localized: "receive.accept")
    static let receiveAccepted = String(localized: "receive.accepted")
    static let receiveRejected = String(localized: "receive.rejected")
    static let receiveOfflineTitle = String(localized: "receive.offline.title")
    static let receiveOfflineDetail = String(localized: "receive.offline.detail")
    static let receiveEmptyTag = String(localized: "receive.empty.tag")
    static let receiveEmptyTitle = String(localized: "receive.empty.title")
    static let receiveEmptyDetail = String(localized: "receive.empty.detail")
    static let receiveInboxTag = String(localized: "receive.inbox.tag")
    static let receiveFilePlaceholder = String(localized: "receive.file.placeholder")
    static let receiveFileSaved = String(localized: "receive.file.saved")
    static let receiveFileTransferring = String(localized: "receive.file.transferring")

    // MARK: Transfer（传输）

    static let transferOfflineTitle = String(localized: "transfer.offline.title")
    static let transferOfflineDetail = String(localized: "transfer.offline.detail")
    static let transferIdleTag = String(localized: "transfer.idle.tag")
    static let transferIdleTitle = String(localized: "transfer.idle.title")
    static let transferIdleDetail = String(localized: "transfer.idle.detail")
    static let transferFooterHint = String(localized: "transfer.footer.hint")
    static let transferStatSpeed = String(localized: "transfer.stat.speed")
    static let transferStatEta = String(localized: "transfer.stat.eta")
    static let transferDefaultName = String(localized: "transfer.default.name")

    // MARK: Complication 预览

    static let complicationTitle = String(localized: "complication.title")
    static let complicationTapHint = String(localized: "complication.tap.hint")

    // MARK: 视图模型 / 桥接错误（surfaced 到 UI 的可读文案）

    static let vmTextLabel = String(localized: "vm.text.label")
    static let vmJustNow = String(localized: "vm.just.now")

    static let errorBridgeUnsupported = String(localized: "error.bridge.unsupported")
    static let errorBridgeUnreachable = String(localized: "error.bridge.unreachable")
    static let errorCommandTimeout = String(localized: "error.command.timeout")
    static let errorCommandFailed = String(localized: "error.command.failed")
    /// "回执格式异常：<detail>"
    static func errorMalformedAck(_ detail: String) -> String {
        String(localized: "error.malformed.ack \(detail)")
    }
    /// "桥接初始化失败：<detail>"
    static func errorBridgeInitFailed(_ detail: String) -> String {
        String(localized: "error.bridge.init.failed \(detail)")
    }
}
