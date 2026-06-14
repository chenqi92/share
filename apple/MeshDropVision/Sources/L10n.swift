import Foundation

/// visionOS 端集中式本地化访问点：所有用户可见文案走 `String(localized:)`，
/// 翻译由 `Localizable.xcstrings` 提供 zh-Hans（默认）/ en 两份。
///
/// why：空间界面文案分散在多块玻璃卡与 ornament 上，集中成常量 / 函数便于静态核对
/// key 完整性，避免裸字符串再硬编码漏翻。
enum L10n {

    // MARK: 通用

    static let commonCancel = String(localized: "common.cancel")

    // MARK: Tab（中文名 + 英文名分两键，并排显示）

    static let tabNearby = String(localized: "tab.nearby")
    static let tabNearbyEn = String(localized: "tab.nearby.en")
    static let tabChats = String(localized: "tab.chats")
    static let tabChatsEn = String(localized: "tab.chats.en")
    static let tabTransfers = String(localized: "tab.transfers")
    static let tabTransfersEn = String(localized: "tab.transfers.en")
    static let tabPairing = String(localized: "tab.pairing")
    static let tabPairingEn = String(localized: "tab.pairing.en")

    // MARK: Nearby（主页 / 空间）

    static let nearbyScanning = String(localized: "nearby.scanning")
    static let nearbyWaiting = String(localized: "nearby.waiting")
    static let nearbyScanningSub = String(localized: "nearby.scanning.sub")
    static let nearbyEmptySub = String(localized: "nearby.empty.sub")
    /// 设备 orb 的无障碍标签。
    static func nearbyOrbA11y(_ who: String) -> String {
        String(localized: "nearby.orb.a11y \(who)")
    }
    /// "发送文件 → <peer>"
    static func nearbySendFileTo(_ who: String) -> String {
        String(localized: "nearby.send.file.to \(who)")
    }
    static let nearbyRevokeTrust = String(localized: "nearby.revoke.trust")
    /// gaze reticle 标签："看向 <PEER> · 准备捏合发送"
    static func nearbyGazeLabel(_ who: String) -> String {
        String(localized: "nearby.gaze.label \(who)")
    }

    // MARK: PeerOrb

    static let peerOnline = String(localized: "peer.online")
    /// "捏合 · 发送 3 张照片 → <peer>"
    static func peerSendCue(_ who: String) -> String {
        String(localized: "peer.send.cue \(who)")
    }

    // MARK: Pairing（配对）

    static let pairingNoPending = String(localized: "pairing.no.pending")
    static let pairingNoPendingSub = String(localized: "pairing.no.pending.sub")
    static let pairingFirstTag = String(localized: "pairing.first.tag")
    static let pairingWaitingConfirm = String(localized: "pairing.waiting.confirm")
    /// "和 <peer>"
    static func pairingWithPeer(_ name: String) -> String {
        String(localized: "pairing.with.peer \(name)")
    }
    static let pairingCompareHint = String(localized: "pairing.compare.hint")
    static let pairingDivider = String(localized: "pairing.divider")
    static let pairingRejectTitle = String(localized: "pairing.reject.title")
    static let pairingRejectSub = String(localized: "pairing.reject.sub")
    static let pairingConfirmTitle = String(localized: "pairing.confirm.title")
    static let pairingConfirmSub = String(localized: "pairing.confirm.sub")
    static let pairingRememberHint = String(localized: "pairing.remember.hint")

    // MARK: Receive（接收弹卡）

    static let receiveNoPending = String(localized: "receive.no.pending")
    static let receiveNoPendingSub = String(localized: "receive.no.pending.sub")
    static let receiveIncomingTag = String(localized: "receive.incoming.tag")
    static let receiveHeroLine1 = String(localized: "receive.hero.line1")
    static let receiveHeroLine2 = String(localized: "receive.hero.line2")
    static let receiveFileTag = String(localized: "receive.file.tag")
    static let receiveDeclineTitle = String(localized: "receive.decline.title")
    static let receiveDeclineSub = String(localized: "receive.decline.sub")
    static let receiveAcceptTitle = String(localized: "receive.accept.title")
    static let receiveAcceptSub = String(localized: "receive.accept.sub")
    static let receiveVoiceHint = String(localized: "receive.voice.hint")
    static let receiveChecksumLabel = String(localized: "receive.checksum.label")
    /// "发送方：<peer>"
    static func receiveSenderLabel(_ name: String) -> String {
        String(localized: "receive.sender.label \(name)")
    }
    /// "接收后会保存到 ~/Documents/MeshDrop/<peer>/"
    static func receiveSavePath(_ name: String) -> String {
        String(localized: "receive.save.path \(name)")
    }
    static let receiveVerifiedHint = String(localized: "receive.verified.hint")
    // 接收卡相对时间标签：刚刚 / N 秒前 / N 分钟前
    static let receiveReceivedJustNow = String(localized: "receive.received.justnow")
    /// "N 秒前"
    static func receiveReceivedSeconds(_ n: Int) -> String {
        String(localized: "receive.received.seconds \(n)")
    }
    /// "N 分钟前"
    static func receiveReceivedMinutes(_ n: Int) -> String {
        String(localized: "receive.received.minutes \(n)")
    }

    // MARK: Transfers（传输）

    static let transferInFlight = String(localized: "transfer.in.flight")
    static let transferEmptyTitle = String(localized: "transfer.empty.title")
    static let transferEmptySub = String(localized: "transfer.empty.sub")
    static let transferActiveDivider = String(localized: "transfer.active.divider")
    static let transferFooterHint = String(localized: "transfer.footer.hint")
    static let transferFailedLabel = String(localized: "transfer.failed.label")
    static let transferSelfName = String(localized: "transfer.self.name")
    /// 文本传输的大小标："N 字"
    static func transferCharCount(_ n: Int) -> String {
        String(localized: "transfer.char.count \(n)")
    }

    // MARK: 状态 ornament + 主窗口

    static let selfInitial = String(localized: "self.initial")
    static let statusScanning = String(localized: "status.scanning")
    static let statusWaiting = String(localized: "status.waiting")
    /// "VISIBLE · N 台"
    static func statusVisibleCount(_ n: Int) -> String {
        String(localized: "status.visible.count \(n)")
    }
    static let statusLanPlaintext = String(localized: "status.lan.plaintext")
    static let resetMenu = String(localized: "reset.menu")
    static let resetConfirm = String(localized: "reset.confirm")
    static let resetAction = String(localized: "reset.action")

    static let windowSpatialTag = String(localized: "window.spatial.tag")
    static let windowWaitingChip = String(localized: "window.waiting.chip")
    static let windowScanningTitle = String(localized: "window.scanning.title")
    static let windowScanningAccent = String(localized: "window.scanning.accent")
    static let windowEmptyTitle = String(localized: "window.empty.title")
    static let windowEmptyAccent = String(localized: "window.empty.accent")
    static let windowEmptyBody = String(localized: "window.empty.body")
    static let windowReadyTitle = String(localized: "window.ready.title")
    static let windowReadyAccent = String(localized: "window.ready.accent")
    static let windowReadyBody = String(localized: "window.ready.body")
    /// "Recent · 最近互动 · 共 N 条"
    static func windowRecentLabel(_ total: Int) -> String {
        String(localized: "window.recent.label \(total)")
    }
    static let windowRecentEmpty = String(localized: "window.recent.empty")
    static let windowHoldHint = String(localized: "window.hold.hint")
    static let windowLanFooter = String(localized: "window.lan.footer")
    /// "文件 · <name> · <size>"
    static func windowFileSnippet(_ name: String, _ size: String) -> String {
        String(localized: "window.file.snippet \(name) \(size)")
    }

    // MARK: 历史状态短标

    static let statusWaitingApproval = String(localized: "status.waiting.approval")
    static let statusTransferring = String(localized: "status.transferring")

    // MARK: Conversations（对话页）

    static let convTitle = String(localized: "conv.title")
    static let convEmptyTitle = String(localized: "conv.empty.title")
    static let convEmptySub = String(localized: "conv.empty.sub")
    /// "[文件 · <name> · <size>]"
    static func convFileSnippet(_ name: String, _ size: String) -> String {
        String(localized: "conv.file.snippet \(name) \(size)")
    }

    // MARK: EngineAdapter

    static let deviceUnnamed = String(localized: "device.unnamed")
}
