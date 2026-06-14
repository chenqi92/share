import Foundation

/// tvOS 端集中式本地化访问点：所有用户可见文案走 `String(localized:)`，
/// 翻译由 `Localizable.xcstrings` 提供 zh-Hans（默认）/ en 两份。
///
/// why：tvOS 3 米外阅读、文案密集且常带计数插值，集中成常量 / 函数便于静态核对
/// key 完整性，避免裸字符串再硬编码漏翻。
enum L10n {

    // MARK: 通用

    static let commonCancel = String(localized: "common.cancel")
    static let commonReject = String(localized: "common.reject")
    static let commonSave = String(localized: "common.save")

    // MARK: Tab 标签（中文名 + 英文名分两键，UI 并排显示）

    static let tabReceive = String(localized: "tab.receive")
    static let tabReceiveEn = String(localized: "tab.receive.en")
    static let tabNearby = String(localized: "tab.nearby")
    static let tabNearbyEn = String(localized: "tab.nearby.en")
    static let tabGallery = String(localized: "tab.gallery")
    static let tabGalleryEn = String(localized: "tab.gallery.en")
    static let tabPairing = String(localized: "tab.pairing")
    static let tabPairingEn = String(localized: "tab.pairing.en")
    static let tabSettings = String(localized: "tab.settings")
    static let tabSettingsEn = String(localized: "tab.settings.en")

    // MARK: 遥控提示

    static let hintBack = String(localized: "hint.back")
    static let hintReturn = String(localized: "hint.return")
    static let hintAcceptSave = String(localized: "hint.accept.save")
    static let hintReject = String(localized: "hint.reject")
    static let hintSelect = String(localized: "hint.select")
    static let hintView = String(localized: "hint.view")
    static let hintEdit = String(localized: "hint.edit")

    // MARK: 顶栏状态

    static let topbarScanning = String(localized: "topbar.scanning")
    /// "客厅 · LIVING ROOM · N 台"
    static func topbarLivingRoomCount(_ n: Int) -> String {
        String(localized: "topbar.livingroom.count \(n)")
    }

    // MARK: Nearby（附近）

    /// 配对引导（带本机显示名）。
    static func nearbyPairIntro(_ name: String) -> String {
        String(localized: "nearby.pair.intro \(name)")
    }
    static let nearbyDividerScan = String(localized: "nearby.divider.scan")
    static let nearbyFingerprintTag = String(localized: "nearby.fingerprint.tag")
    static let nearbyThisTVTag = String(localized: "nearby.thistv.tag")
    static let nearbyEmpty = String(localized: "nearby.empty")
    /// "附近 N 台 · NEARBY · 客厅可见"
    static func nearbyHeaderCount(_ n: Int) -> String {
        String(localized: "nearby.header.count \(n)")
    }

    // MARK: Receive（接收）

    static let receiveWaitingHero = String(localized: "receive.waiting.hero")
    static let receiveIdleTag = String(localized: "receive.idle.tag")
    /// 等候面板说明（带本机显示名）。
    static func receiveIdleBody(_ name: String) -> String {
        String(localized: "receive.idle.body \(name)")
    }
    /// "附近 · NEARBY · N 台"
    static func receiveNearbyDivider(_ n: Int) -> String {
        String(localized: "receive.nearby.divider \(n)")
    }
    static let receiveNearbyEmpty = String(localized: "receive.nearby.empty")
    static let receiveFrom = String(localized: "receive.from")
    static let receiveAcceptSave = String(localized: "receive.accept.save")
    static let receiveAcceptSaveSub = String(localized: "receive.accept.save.sub")
    static let receiveDecline = String(localized: "receive.decline")
    static let receiveDeclineSub = String(localized: "receive.decline.sub")
    static let receivePlaintextTag = String(localized: "receive.plaintext.tag")

    // MARK: Gallery（收件箱）

    static let galleryFilterAll = String(localized: "gallery.filter.all")
    static let galleryFilterPhotos = String(localized: "gallery.filter.photos")
    static let galleryFilterFiles = String(localized: "gallery.filter.files")
    // 并排英文副标（恒定 ASCII 强调，两份语言取同值）
    static let galleryFilterAllEn = String(localized: "gallery.filter.all.en")
    static let galleryFilterPhotosEn = String(localized: "gallery.filter.photos.en")
    static let galleryFilterFilesEn = String(localized: "gallery.filter.files.en")
    /// "N 件"
    static func galleryCount(_ n: Int) -> String {
        String(localized: "gallery.count \(n)")
    }
    static let galleryDividerInboxEmpty = String(localized: "gallery.divider.inbox.empty")
    static let galleryDividerInbox = String(localized: "gallery.divider.inbox")
    static let galleryEmptyTag = String(localized: "gallery.empty.tag")
    static let galleryEmptyBody = String(localized: "gallery.empty.body")
    static let galleryUnnamed = String(localized: "gallery.unnamed")
    static let galleryYesterday = String(localized: "gallery.yesterday")

    // MARK: Pairing（配对）

    static let pairingDividerFingerprint = String(localized: "pairing.divider.fingerprint")
    static let pairingNoPending = String(localized: "pairing.no.pending")
    static let pairingScanTag = String(localized: "pairing.scan.tag")
    static let pairingScanHint = String(localized: "pairing.scan.hint")
    static let pairingStep1 = String(localized: "pairing.step1")
    static let pairingStep2 = String(localized: "pairing.step2")
    static let pairingStep3 = String(localized: "pairing.step3")
    /// "指纹: <fingerprint>"
    static func pairingPeerFingerprint(_ fp: String) -> String {
        String(localized: "pairing.peer.fingerprint \(fp)")
    }
    static let pairingTrust = String(localized: "pairing.trust")
    static let pairingReject = String(localized: "pairing.reject")

    // MARK: Settings（设置）

    static let settingsDivider = String(localized: "settings.divider")
    static let settingsRowDisplayName = String(localized: "settings.row.display.name")
    static let settingsRowSavePath = String(localized: "settings.row.save.path")
    static let settingsRowSavePathValue = String(localized: "settings.row.save.path.value")
    static let settingsRowNetwork = String(localized: "settings.row.network")
    static let settingsRowBehavior = String(localized: "settings.row.behavior")
    static let settingsRowBehaviorValue = String(localized: "settings.row.behavior.value")
    static let settingsRowReset = String(localized: "settings.row.reset")
    static let settingsRowResetValue = String(localized: "settings.row.reset.value")
    // 设置项并排英文副标（恒定 ASCII 强调，两份语言取同值）
    static let settingsRowDisplayNameEn = String(localized: "settings.row.display.name.en")
    static let settingsRowSavePathEn = String(localized: "settings.row.save.path.en")
    static let settingsRowNetworkEn = String(localized: "settings.row.network.en")
    static let settingsRowBehaviorEn = String(localized: "settings.row.behavior.en")
    static let settingsRowResetEn = String(localized: "settings.row.reset.en")
    static let settingsNameEditorTag = String(localized: "settings.name.editor.tag")
    static let settingsNamePlaceholder = String(localized: "settings.name.placeholder")
    static let settingsResetConfirm = String(localized: "settings.reset.confirm")
    static let settingsResetAction = String(localized: "settings.reset.action")
    static let settingsFingerprintTag = String(localized: "settings.fingerprint.tag")
    static let settingsFingerprintHint = String(localized: "settings.fingerprint.hint")

    // MARK: 页头（TVRoot）—— tag / title / accent 三段拼装

    /// "接收 · RECEIVE · 来自 <peer>"
    static func headerReceiveTag(_ peer: String) -> String {
        String(localized: "header.receive.tag \(peer)")
    }
    /// "<peer> 想发给你 "
    static func headerReceiveTitle(_ peer: String) -> String {
        String(localized: "header.receive.title \(peer)")
    }
    static let headerReceiveWaitingTag = String(localized: "header.receive.waiting.tag")
    static let headerReceiveWaitingTitle = String(localized: "header.receive.waiting.title")

    static let headerNearbyScan = String(localized: "header.nearby.scan")
    static let headerNearbyReady = String(localized: "header.nearby.ready")
    static let headerNearbyTitle = String(localized: "header.nearby.title")

    /// "收件箱 · LIBRARY · N 件"
    static func headerGalleryTag(_ n: Int) -> String {
        String(localized: "header.gallery.tag \(n)")
    }
    static let headerGalleryTitle = String(localized: "header.gallery.title")

    static let headerPairingTag = String(localized: "header.pairing.tag")
    static let headerPairingTitle = String(localized: "header.pairing.title")
    static let headerPairingAccent = String(localized: "header.pairing.accent")

    static let headerSettingsTag = String(localized: "header.settings.tag")
    static let headerSettingsTitle = String(localized: "header.settings.title")

    // MARK: 通用 chip（页头 / 卡片复用）

    /// "N 台可见"
    static func chipVisibleCount(_ n: Int) -> String {
        String(localized: "chip.visible.count \(n)")
    }
    /// "N 待审"
    static func chipPendingCount(_ n: Int) -> String {
        String(localized: "chip.pending.count \(n)")
    }
    static let chipPlaintext = String(localized: "chip.plaintext")
    static let netTagScanning = String(localized: "net.tag.scanning")
    static let netTagLivingRoom = String(localized: "net.tag.livingroom")
}
