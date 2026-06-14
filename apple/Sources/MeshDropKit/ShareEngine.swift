import Foundation
import Network
import Combine
import CryptoKit
import ImageIO
import OSLog
import UniformTypeIdentifiers

private let log = Logger(subsystem: "com.welape.meshdrop", category: "Engine")

/// 顶层引擎：单例。持有 [Identity]、[Discovery]、[TrustStore]，对外暴露设备列表、
/// 发送/接收历史、待审配对请求、待审文件 offer。
///
/// 完整链路：
/// - 文本发送：UI → `sendText(to:content:)` → 出方 [Connection] → HELLO/ACK → TEXT → 关
/// - 文件发送：UI → `sendFile(to:url:)` → 出方 [Connection] → HELLO/ACK → FILE_OFFER →
///   FILE_ACCEPT → 流式 FILE_CHUNK → FILE_COMPLETE → 关
/// - 接收：listener accept → HELLO → ACK → 收到 TEXT 直接入 history；收到 FILE_OFFER
///   投递 [PendingFileOffer]，用户接受后 send FILE_ACCEPT 进入接收，chunk 累积写盘，
///   收齐校验 sha256 后 send FILE_COMPLETE。
@MainActor
public final class ShareEngine: ObservableObject {
    public static let shared = ShareEngine()

    @Published public private(set) var devices: [Device] = []
    @Published public private(set) var history: [HistoryItem] = []
    @Published public private(set) var pendingPairings: [PairingRequest] = []
    @Published public private(set) var pendingFileOffers: [PendingFileOffer] = []
    @Published public private(set) var trusted: [TrustRecord] = []
    @Published public private(set) var identity: Identity
    @Published public var displayName: String

    /// 进行中传输的实时速率 / 剩余时间。Key 为 history.id。
    /// 进入 .completed / .failed / .canceled 时由 closeContext / updateHistoryStatus
    /// 移除条目，UI 上速率显示会跟着消失。
    @Published public private(set) var transferMetrics: [UUID: TransferMetrics] = [:]

    /// 剪贴板收件箱：对端显式推来的剪贴板条目（最新在前），不进聊天历史。
    @Published public private(set) var clipboardInbox: [ClipboardEntry] = []

    /// 会话级吞吐时间序列（每秒采样，最新在后），供传输页速度柱状图绘制真实数据。
    @Published public private(set) var sessionThroughput = SessionThroughput()

    /// 每个对端未读的入站文本条数（key = peer.id）。收到入站文本时 +1；
    /// UI 打开对应会话时调 markRead(peerID:) 清零。聊天 tab 角标 = unreadTotal。
    @Published public private(set) var unreadByPeer: [String: Int] = [:]
    public var unreadTotal: Int { unreadByPeer.values.reduce(0, +) }

    /// 打开某对端会话时清掉其未读计数。
    public func markRead(peerID: String) {
        if unreadByPeer[peerID] != nil { unreadByPeer[peerID] = nil }
    }

    /// 设置：收到来自已信任设备的文件 offer 时自动接受（持久化到 UserDefaults）。
    @Published public var autoAcceptFromTrusted: Bool =
        UserDefaults.standard.bool(forKey: "meshdrop.autoAcceptTrusted") {
        didSet { UserDefaults.standard.set(autoAcceptFromTrusted, forKey: "meshdrop.autoAcceptTrusted") }
    }

    /// 设置：收到入站内容时弹系统通知（默认开；持久化到 UserDefaults）。IncomingNotifier 据此决定是否弹。
    @Published public var notificationsEnabled: Bool =
        (UserDefaults.standard.object(forKey: "meshdrop.notify") as? Bool) ?? true {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "meshdrop.notify") }
    }

    /// 是否处于"启动 / 扫描 LAN"阶段。UI 顶部 banner 用。
    /// true  = 启动中 / 扫描中（mDNS 已开但尚未收齐首批设备 / 3s 超时前）
    /// false = 已稳定（收到首批设备 或 3s 超时；或未启动 / 已 stop）
    @Published public private(set) var isStarting: Bool = false
    /// 最近一次启动 / 网络层错误的可读文案，nil 表示无错。
    @Published public private(set) var lastError: String?

    private var discovery: Discovery?
    private let trustStore = TrustStore()
    private let resumeStore = ResumeStore()
    private var devicesTask: Task<Void, Never>?
    private var throughputTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var contexts: [UUID: ConnectionContext] = [:]

    /// 重放去重（security.md §重放）：记录最近见过的 `(peer_fp, message_id)` → 首见时刻，
    /// 5 分钟窗口内重复命中即丢弃。TEXT / CLIPBOARD / FILE_OFFER 用 message id 去重。
    private var seenMessages: [String: Date] = [:]
    /// transfer_id → 持有它的连接 ctx.id，保证同一 transfer_id 不被跨连接复用。
    private var transferOwners: [UUID: UUID] = [:]
    /// 重放窗口：5 分钟（security.md）。
    private static let replayWindow: TimeInterval = 5 * 60

    /// 握手超时：纯机器协商态（awaitingHello/awaitingHelloAck）应在秒级完成，
    /// 超过这么久仍没推进即判死回收，防半开连接堆积。
    private static let handshakeTimeout: TimeInterval = 30
    /// 决策超时：awaitingPairApproval / awaitingFileAccept 等待的是**人**点「信任」/「接收」，
    /// 不能用 30s 机器握手超时硬切（用户常隔几十秒才看到弹窗）。给一个宽松窗口兜底回收僵尸连接。
    private static let decisionTimeout: TimeInterval = 5 * 60
    /// 心跳：每 30s 给 .ready/.receivingFile/.sendingFile 的连接发 PING；连续丢 3 次 PONG 关连接。
    private static let heartbeatInterval: TimeInterval = 30
    private static let maxMissedPongs = 3
    /// FILE_CHUNK 单帧 data 硬上限 4 MiB（messages.md），超限视为协议错误关连接。
    private static let maxChunkBytes = 4 * 1024 * 1024

    /// 吞吐环形缓冲保留的秒数（柱状图横轴长度）。
    private static let throughputBuckets = 32

    /// 接收 chunk 时每写满这么多字节就把进度刷一次 ResumeStore。
    /// 4 MiB ≈ 16 个 256 KiB chunk —— 平衡崩溃时丢失上限和 I/O 频次。
    private static let resumePersistInterval: UInt64 = 4 * 1024 * 1024

    private init() {
        self.identity = IdentityStore.loadOrCreate()
        self.displayName = Self.defaultDisplayName()
    }

    #if DEBUG
    /// 仅 DEBUG / 离线截图预览用：注入一组演示数据（设备 / 历史 / 信任 / 待接收 / 待配对 /
    /// 吞吐），不触发任何网络或权限请求。app 检测到 `MESHDROP_PREVIEW_ROUTE` 时调用；
    /// release 构建由 `#if DEBUG` 完全排除，假名 / 假数据不会进入发布产物。
    @MainActor
    public func seedPreviewData(route: String) {
        func dev(_ id: String, who: String, model: String, _ os: DeviceOS, _ fp: String) -> Device {
            Device(id: id, name: who, os: os, model: model, fingerprint: fp, port: 9580)
        }
        let lily   = dev("a1b2c3d4e5f60718293a4b5c6d7e8f90", who: "李莉",   model: "Lily's MacBook",  .macos,   "9f3a7c2e8b1d40563a9e7c3201ab77de")
        let kun    = dev("b2c3d4e5f6071829304a5b6c7d8e9f01", who: "坤",     model: "Kun · Pixel 8",    .android, "1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f")
        let jiawei = dev("c3d4e5f60718293041a5b6c7d8e9f012", who: "嘉伟",   model: "Jiawei · iPad",    .ios,     "2233445566778899aabbccddeeff0011")
        let mengxi = dev("d4e5f6071829304152b6c7d8e9f01234", who: "孟茜",   model: "Meng Xi · iPhone", .ios,     "7788990011223344556677889900aabb")
        let dev01  = dev("e5f607182930415263c7d8e9f0123456", who: "工位机", model: "DEV-01 · Win 11",  .windows, "aabbccddeeff00112233445566778899")
        devices = [lily, kun, jiawei, mengxi, dev01]

        let now = Date()
        func ago(_ minutes: Int) -> Date { now.addingTimeInterval(Double(-minutes) * 60) }
        history = [
            HistoryItem(peer: jiawei, direction: .outgoing, kind: .file(name: "iOS-mocks-final.zip", size: 48_600_000, url: nil),
                        status: .transferring(bytesDone: 32_500_000, bytesTotal: 48_600_000), createdAt: ago(1)),
            HistoryItem(peer: kun, direction: .incoming, kind: .file(name: "IMG_4821~38.heic", size: 128_000_000, url: nil),
                        status: .transferring(bytesDone: 15_360_000, bytesTotal: 128_000_000), createdAt: ago(1)),
            HistoryItem(peer: lily, direction: .outgoing, kind: .file(name: "demo-video.mp4", size: 512_000_000, url: nil),
                        status: .pending, createdAt: ago(2)),
            HistoryItem(peer: mengxi, direction: .incoming, kind: .file(name: "IMG_4821.heic", size: 2_400_000, url: nil),
                        status: .completed, createdAt: ago(4)),
            HistoryItem(peer: jiawei, direction: .outgoing, kind: .file(name: "设计稿_v3_final.fig", size: 14_200_000, url: nil),
                        status: .completed, createdAt: ago(6)),
            HistoryItem(peer: lily, direction: .outgoing, kind: .text("改完了，整理一下发你"), status: .completed, createdAt: ago(8)),
            HistoryItem(peer: mengxi, direction: .incoming, kind: .text("收到，下午开会前给反馈"), status: .completed, createdAt: ago(9)),
            HistoryItem(peer: mengxi, direction: .outgoing, kind: .text("嘉伟说图改完了，我转给你看下"), status: .completed, createdAt: ago(10)),
        ]
        transferMetrics = [
            history[0].id: TransferMetrics(bytesPerSec: 6_200_000, etaSeconds: 2.6),
            history[1].id: TransferMetrics(bytesPerSec: 4_100_000, etaSeconds: 27),
        ]
        var upSeries: [Double] = []
        var downSeries: [Double] = []
        for i in 0..<32 {
            let t = Double(i)
            upSeries.append(3_500_000.0 + 2_400_000.0 * (0.5 + 0.5 * sin(t / 3.0)))
            downSeries.append(5_000_000.0 + 3_000_000.0 * (0.5 + 0.5 * sin(t / 2.3 + 1.0)))
        }
        sessionThroughput = SessionThroughput(up: upSeries, down: downSeries)
        // 待接收 / 待配对会被 PhoneRoot 自动弹成 sheet，因此只在对应截图路由下注入，
        // 避免盖住 discover / transfers 等其它页面。
        if route == "receive" {
            pendingFileOffers = [
                PendingFileOffer(id: UUID(), peer: mengxi, fileName: "设计稿_v3_final.fig",
                                 fileSize: 14_200_000,
                                 sha256: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                                 mime: nil, previewBase64: nil, receivedAt: now)
            ]
        }
        if route == "pairing" {
            pendingPairings = [
                PairingRequest(peer: dev01, receivedAt: now)
            ]
        }
        trusted = [
            TrustRecord(fingerprint: lily.fingerprint,   name: lily.model ?? lily.name,   firstSeen: ago(60 * 24), lastSeen: ago(8)),
            TrustRecord(fingerprint: mengxi.fingerprint, name: mengxi.model ?? mengxi.name, firstSeen: ago(60 * 48), lastSeen: ago(4)),
            TrustRecord(fingerprint: jiawei.fingerprint, name: jiawei.model ?? jiawei.name, firstSeen: ago(60 * 12), lastSeen: ago(6)),
        ]
        unreadByPeer = [mengxi.id: 2]
        isStarting = false
    }
    #endif

    // MARK: - 生命周期

    public func start() {
        guard discovery == nil else { return }
        isStarting = true
        lastError = nil
        do {
            let d = try Discovery(
                identity: identity,
                displayName: displayName,
                model: Self.systemModel()
            )
            d.onIncomingConnection = { [weak self] nwConn in
                guard let self else { nwConn.cancel(); return }
                Task { @MainActor in await self.acceptIncoming(nwConn) }
            }
            try d.start()
            discovery = d
            devicesTask = Task { [weak self] in
                guard let self else { return }
                for await list in d.devices {
                    await MainActor.run {
                        self.devices = list
                        // 收到首批设备 / 至少完成一轮浏览后视为不再扫描
                        if self.isStarting { self.isStarting = false }
                    }
                }
            }
            Task { await refreshTrusted() }
            // 每秒采样一次会话吞吐，喂给传输页速度柱状图。
            throughputTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self else { return }
                    self.sampleThroughput()
                }
            }
            // 每秒巡检：握手超时回收 + 周期性 PING + 丢 PONG 判死。
            heartbeatTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self else { return }
                    await self.tickConnectionHealth()
                }
            }
            // 即使 LAN 上暂时一台都没有也算启动完成；3 秒后清掉 isStarting
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { self?.isStarting = false }
            }
        } catch {
            isStarting = false
            lastError = error.localizedDescription
            log.error("ShareEngine start failed: \(error.localizedDescription)")
        }
    }

    public func stop() {
        discovery?.stop()
        discovery = nil
        devicesTask?.cancel()
        devicesTask = nil
        throughputTask?.cancel()
        throughputTask = nil
        heartbeatTask?.cancel()
        heartbeatTask = nil
        seenMessages.removeAll()
        transferOwners.removeAll()
        sessionThroughput = SessionThroughput()
        devices = []
        isStarting = false
        let active = Array(contexts.values)
        contexts.removeAll()
        Task { for ctx in active { await ctx.connection.close() } }
    }

    /// 清空最近的错误（UI toast 关闭时调用）。
    public func clearLastError() {
        lastError = nil
    }

    public func setDisplayName(_ name: String) {
        displayName = name
    }

    /// 重置设备身份（security.md §设备身份）。
    /// 用户在 Settings 里点"重置身份"时调用。
    ///
    /// 步骤：
    /// 1. 停 discovery（避免广播旧 fp）
    /// 2. 清 history（旧身份下的会话与新身份无关）
    /// 3. IdentityStore.reset() 删 Keychain 条目 + UserDefaults
    /// 4. 重新 load 生成新的 Ed25519 keypair + 新 device id + 新 fp
    /// 5. 如果之前在跑，重启 discovery 以新身份广告
    ///
    /// 信任库（trustedDevices.json）**保留** —— 那是别人 → 我的信任关系，
    /// 我换身份不该影响。但其它端会发现我是"新设备"，他们要重新审我。
    public func resetIdentity() {
        let wasRunning = (discovery != nil)
        stop()
        history.removeAll()
        IdentityStore.reset()
        identity = IdentityStore.loadOrCreate()
        log.info("identity reset: new id=\(self.identity.id) fp=\(self.identity.fingerprint)")
        if wasRunning {
            start()
        }
    }

    // MARK: - 历史管理

    public func removeHistoryItem(_ id: UUID) {
        history.removeAll { $0.id == id }
    }

    public func clearHistory() {
        history.removeAll()
    }

    // MARK: - 发送文本

    public func sendText(to device: Device, content: String) {
        let historyItem = HistoryItem(
            peer: device,
            direction: .outgoing,
            kind: .text(content),
            status: .pending
        )
        history.insert(historyItem, at: 0)

        let conn = Connection(connectingTo: device)
        let ctx = ConnectionContext(
            connection: conn,
            role: .client(target: device, payload: .text(content)),
            state: .awaitingHelloAck
        )
        ctx.historyID = historyItem.id
        contexts[ctx.id] = ctx
        startConnection(ctx)
    }

    // MARK: - 剪贴板推送

    /// 显式把一段剪贴板内容推给对端（隐私上仅在用户点按时调用，不后台同步）。
    /// 复用 TEXT 的连接生命周期；本端不留收件箱记录（只有接收方进 inbox）。
    public func pushClipboard(to device: Device, content: String, kind: String = "text") {
        guard !content.isEmpty else { return }
        let conn = Connection(connectingTo: device)
        let ctx = ConnectionContext(
            connection: conn,
            role: .client(target: device, payload: .clipboard(content: content, kind: kind)),
            state: .awaitingHelloAck
        )
        contexts[ctx.id] = ctx
        startConnection(ctx)
    }

    // MARK: - 发送文件

    /// 批量发送：每个 URL 独立 offer + 独立 history 条目，按顺序触发 sendFile。
    /// 当前实现是串行入队（每次 sendFile 都建一条新连接）；
    /// 后续可优化为同连接复用 FILE_OFFER (files: [...])，但需要协议层扩展。
    public func sendFiles(to device: Device, sourceURLs: [URL]) {
        for url in sourceURLs {
            sendFile(to: device, sourceURL: url)
        }
    }

    public func sendFile(to device: Device, sourceURL: URL) {
        let needsAccess = sourceURL.startAccessingSecurityScopedResource()
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            let fileSize = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
            let fileName = sourceURL.lastPathComponent

            // 占位历史项（先 pending，之后计算 sha256）
            let historyItem = HistoryItem(
                peer: device,
                direction: .outgoing,
                kind: .file(name: fileName, size: fileSize, url: sourceURL),
                status: .pending
            )
            history.insert(historyItem, at: 0)
            let historyID = historyItem.id

            // 后台算 sha256（大文件流式），算完后启动连接
            let engineRef = self
            Task.detached(priority: .userInitiated) {
                let hash: String
                do {
                    hash = try Self.sha256OfFile(at: sourceURL)
                } catch {
                    if needsAccess { sourceURL.stopAccessingSecurityScopedResource() }
                    let msg = error.localizedDescription
                    await MainActor.run { [weak engineRef] in
                        engineRef?.updateHistoryStatus(historyID, status: .failed(L10n.failReadFile(msg)))
                    }
                    return
                }
                await MainActor.run { [weak engineRef] in
                    engineRef?.startFileSend(
                        to: device,
                        historyID: historyID,
                        sourceURL: sourceURL,
                        fileSize: fileSize,
                        sha256: hash,
                        needsSecurityScope: needsAccess
                    )
                }
            }
        } catch {
            if needsAccess { sourceURL.stopAccessingSecurityScopedResource() }
            log.error("sendFile failed: \(error.localizedDescription)")
        }
    }

    private func startFileSend(
        to device: Device,
        historyID: UUID,
        sourceURL: URL,
        fileSize: UInt64,
        sha256: String,
        needsSecurityScope: Bool
    ) {
        let transferID = UUID()
        let conn = Connection(connectingTo: device)
        let payload = ConnectionContext.ClientPayload.file(
            sourceURL: sourceURL,
            fileSize: fileSize,
            sha256: sha256,
            needsSecurityScope: needsSecurityScope
        )
        let ctx = ConnectionContext(
            connection: conn,
            role: .client(target: device, payload: payload),
            state: .awaitingHelloAck
        )
        ctx.historyID = historyID
        ctx.transferID = transferID
        ctx.fileSize = fileSize
        contexts[ctx.id] = ctx
        updateHistoryStatus(historyID, status: .waitingApproval)
        startConnection(ctx)
    }

    // MARK: - 配对决定

    public func respondToPairing(_ requestID: UUID, decision: PairingDecision) {
        guard let req = pendingPairings.first(where: { $0.id == requestID }) else { return }
        pendingPairings.removeAll { $0.id == requestID }

        let entry = contexts.first { _, c in
            if case .awaitingPairApproval(let r) = c.state, r.id == requestID { return true }
            return false
        }
        guard let (ctxID, _) = entry else { return }
        Task {
            switch decision {
            case .reject:
                await closeContext(id: ctxID, error: nil)
            case .allowOnce:
                await sendAckAndReady(contextID: ctxID, peer: req.peer)
            case .trust:
                await trustStore.trust(fingerprint: req.peer.fingerprint, name: req.peer.name)
                await refreshTrusted()
                await sendAckAndReady(contextID: ctxID, peer: req.peer)
            }
        }
    }

    public func revokeTrust(fingerprint: String) {
        Task { await trustStore.revoke(fingerprint); await refreshTrusted() }
    }

    // MARK: - 文件 Offer 决定

    /// 主动取消进行中的传输（发送端或接收端都能调）。
    /// 找到 historyID 对应的 ConnectionContext，发 FILE_CANCEL 给对端，
    /// 接收态下清半成品 + ResumeStore，最后关 ctx。
    public func cancelTransfer(_ historyID: UUID) {
        let entry = contexts.first { _, c in c.historyID == historyID }
        guard let (ctxID, ctx) = entry else {
            // ctx 已不在（可能传输已结束 / 早已关）；只更新历史
            updateHistoryStatus(historyID, status: .canceled)
            return
        }
        let transferID = ctx.transferID
        let isReceiving: Bool = {
            if case .receivingFile = ctx.state { return true } else { return false }
        }()
        let peer = ctx.peer
        let expectedSHA = ctx.expectedSHA256

        // 接收态：先关 handle + 删半成品 + 清 ResumeStore
        if isReceiving {
            try? ctx.fileHandle?.close()
            ctx.fileHandle = nil
            if let saved = ctx.savedURL {
                try? FileManager.default.removeItem(at: saved)
            }
            if let p = peer, let sha = expectedSHA {
                Task { await resumeStore.clear(peerFingerprint: p.fingerprint, sha256: sha) }
            }
        }

        // 发 FILE_CANCEL 给对端（whole transfer，index=null）
        Task {
            if let tid = transferID {
                let body = try? MessageCodec.encode(FileCancelMessage(
                    transfer_id: tid.uuidString,
                    index: nil,
                    reason: "user_canceled"
                ))
                if let body { try? await ctx.connection.send(type: MessageType.fileCancel, body: body) }
            }
            await self.closeContext(id: ctxID, error: nil)
        }
        updateHistoryStatus(historyID, status: .canceled)
    }

    /// 失败 / 取消的发送项重试。
    /// 找 historyID 对应的 outgoing 历史项；若 kind 是 file 且 url 仍可读，
    /// 调用 sendFile 走完整流程（新建一个独立的 history 条目，旧的失败条目不动）。
    /// 返回 true 表示触发了重发；false 表示找不到 / 不是文件 / 源文件已失效。
    @discardableResult
    public func retryTransfer(_ historyID: UUID) -> Bool {
        guard let item = history.first(where: { $0.id == historyID }),
              item.direction == .outgoing,
              case .file(_, _, let url) = item.kind,
              let sourceURL = url,
              FileManager.default.fileExists(atPath: sourceURL.path) else {
            return false
        }
        sendFile(to: item.peer, sourceURL: sourceURL)
        return true
    }

    public func respondToFileOffer(_ offerID: UUID, accept: Bool) {
        guard let offer = pendingFileOffers.first(where: { $0.id == offerID }) else { return }
        pendingFileOffers.removeAll { $0.id == offerID }

        // 找对应连接
        let entry = contexts.first { _, c in c.pendingOfferID == offerID }
        guard let (ctxID, ctx) = entry else { return }

        if !accept {
            // 发 REJECT 再关
            Task {
                let body = try? MessageCodec.encode(FileRejectMessage(
                    transfer_id: offer.id.uuidString,
                    index: 0,
                    reason: "user_declined"
                ))
                if let body { try? await ctx.connection.send(type: MessageType.fileReject, body: body) }
                await closeContext(id: ctxID, error: nil)
            }
            return
        }

        // 接受：创建保存路径 + 打开 file handle + 发 ACCEPT + 进入 receiving 状态
        let saveURL = Self.uniqueFileURL(
            in: Self.defaultSaveDir(for: offer.peer),
            fileName: offer.fileName
        )
        do {
            FileManager.default.createFile(atPath: saveURL.path, contents: nil)
            let handle = try FileHandle(forWritingTo: saveURL)
            ctx.fileHandle = handle
            ctx.savedURL = saveURL
            ctx.fileSize = offer.fileSize
            ctx.expectedSHA256 = offer.sha256
            ctx.transferID = offer.id
            ctx.pendingOfferID = nil
            ctx.state = .receivingFile

            // 创建历史项
            let item = HistoryItem(
                peer: offer.peer,
                direction: .incoming,
                kind: .file(name: offer.fileName, size: offer.fileSize, url: saveURL),
                status: .transferring(bytesDone: 0, bytesTotal: offer.fileSize)
            )
            history.insert(item, at: 0)
            ctx.historyID = item.id

            Task {
                let body = try? MessageCodec.encode(FileAcceptMessage(
                    transfer_id: offer.id.uuidString,
                    index: 0,
                    resume_offset: 0
                ))
                if let body {
                    try? await ctx.connection.send(type: MessageType.fileAccept, body: body)
                }
            }
        } catch {
            log.error("open save handle failed: \(error.localizedDescription)")
            Task { await closeContext(id: ctxID, error: error) }
        }
    }

    // MARK: - 入站连接

    private func acceptIncoming(_ nwConn: NWConnection) async {
        let conn = Connection(nwConnection: nwConn)
        let ctx = ConnectionContext(connection: conn, role: .server, state: .awaitingHello)
        contexts[ctx.id] = ctx
        let ctxID = ctx.id
        await conn.start(
            onReady: { },
            onMessage: { [weak self] type, body in
                await self?.handleMessage(type: type, body: body, contextID: ctxID)
            },
            onClose: { [weak self] err in
                await self?.closeContext(id: ctxID, error: err)
            }
        )
    }

    private func startConnection(_ ctx: ConnectionContext) {
        let ctxID = ctx.id
        Task {
            await ctx.connection.start(
                onReady: { [weak self] in
                    await self?.sendInitialHello(contextID: ctxID)
                },
                onMessage: { [weak self] type, body in
                    await self?.handleMessage(type: type, body: body, contextID: ctxID)
                },
                onClose: { [weak self] err in
                    await self?.closeContext(id: ctxID, error: err)
                }
            )
        }
    }

    // MARK: - 消息路由

    private func handleMessage(type: UInt8, body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }
        // 任何入站帧都刷新心跳活性，清掉丢 PONG 计数。
        ctx.lastInboundAt = Date()
        ctx.missedPongs = 0

        switch (ctx.state, type) {
        case (.awaitingHello, MessageType.hello):
            await serverReceivedHello(body: body, contextID: contextID)

        case (.awaitingHelloAck, MessageType.helloAck):
            await clientReceivedAck(body: body, contextID: contextID)

        case (.awaitingFileAccept, MessageType.fileAccept):
            await clientStartSending(contextID: contextID, acceptBody: body)

        case (.awaitingFileAccept, MessageType.fileReject):
            if let hid = ctx.historyID {
                let reason = (try? MessageCodec.decode(FileRejectMessage.self, from: body).reason) ?? "rejected"
                updateHistoryStatus(hid, status: .failed(L10n.failPeerRejected(reason)))
            }
            await closeContext(id: contextID, error: nil)

        case (.sendingFile, MessageType.fileComplete):
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .completed) }
            await closeContext(id: contextID, error: nil)

        case (.ready, MessageType.text):
            handleReceivedText(body: body, contextID: contextID)

        case (.ready, MessageType.clipboard):
            handleReceivedClipboard(body: body, contextID: contextID)

        case (.ready, MessageType.fileOffer):
            handleReceivedFileOffer(body: body, contextID: contextID)

        case (.receivingFile, MessageType.fileChunk):
            await handleReceivedChunk(body: body, contextID: contextID)

        case (_, MessageType.ping):
            try? await ctx.connection.send(type: MessageType.pong, body: Data("{}".utf8))

        case (_, MessageType.pong):
            break

        case (_, MessageType.fileCancel):
            // 对端取消：接收态需删半成品 + 清 ResumeStore，避免之后被误判为可续传。
            if case .receivingFile = ctx.state {
                try? ctx.fileHandle?.close()
                ctx.fileHandle = nil
                if let saved = ctx.savedURL {
                    try? FileManager.default.removeItem(at: saved)
                }
                if let peer = ctx.peer, let expected = ctx.expectedSHA256 {
                    await resumeStore.clear(peerFingerprint: peer.fingerprint, sha256: expected)
                }
            }
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .canceled) }
            await closeContext(id: contextID, error: nil)

        default:
            log.info("drop unexpected type=\(type) in state=\(String(describing: ctx.state))")
            await closeContext(id: contextID, error: nil)
        }
    }

    // MARK: - HELLO 握手

    private func sendInitialHello(contextID: UUID) async {
        guard contexts[contextID] != nil else { return }
        let hello = HelloMessage(
            id: identity.id,
            name: displayName,
            os: .current,
            model: Self.systemModel(),
            fp: identity.fingerprint,
            protocol_versions: [1]
        )
        do {
            let body = try MessageCodec.encode(hello)
            try await contexts[contextID]?.connection.send(type: MessageType.hello, body: body)
        } catch {
            await closeContext(id: contextID, error: error)
        }
    }

    private func serverReceivedHello(body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }
        guard let hello = try? MessageCodec.decode(HelloMessage.self, from: body) else {
            await closeContext(id: contextID, error: nil); return
        }
        guard Set<UInt8>([1]).intersection(hello.protocol_versions).max() != nil else {
            await closeContext(id: contextID, error: nil); return
        }
        let peer = Device(
            id: hello.id, name: hello.name, os: hello.os, model: hello.model,
            fingerprint: hello.fp, port: 0, protocolVersion: 1
        )
        ctx.peer = peer
        if await trustStore.isTrusted(hello.fp) {
            await trustStore.touch(fingerprint: hello.fp)
            await refreshTrusted()
            await sendAckAndReady(contextID: contextID, peer: peer)
        } else {
            let req = PairingRequest(peer: peer)
            ctx.state = .awaitingPairApproval(req)
            pendingPairings.append(req)
        }
    }

    private func sendAckAndReady(contextID: UUID, peer: Device) async {
        guard let ctx = contexts[contextID] else { return }
        let ack = HelloAckMessage(
            id: identity.id, name: displayName, os: .current,
            model: Self.systemModel(), fp: identity.fingerprint,
            protocol_versions: [1], selected_version: 1
        )
        do {
            let body = try MessageCodec.encode(ack)
            try await ctx.connection.send(type: MessageType.helloAck, body: body)
            ctx.state = .ready
            ctx.peer = peer
        } catch {
            await closeContext(id: contextID, error: error)
        }
    }

    private func clientReceivedAck(body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID] else { return }
        guard let ack = try? MessageCodec.decode(HelloAckMessage.self, from: body) else {
            await closeContext(id: contextID, error: nil); return
        }
        guard case .client(let target, let payload) = ctx.role else {
            await closeContext(id: contextID, error: nil); return
        }
        // v0.1 明文阶段：fp 仅与 TXT 广告里的 fingerprint 比对，未绑定任何公钥/证书，
        // 因此只防误连、不抗主动 MITM（攻击者可伪造 fp）。v1.0 接 TLS 后须改为「从证书公钥导出
        // fp 再比对 TXT/HELLO」。UI 对指纹核对的安全承诺措辞需与此保守现状一致。
        guard ack.fp == target.fingerprint else {
            log.info("server fp mismatch; closing")
            await closeContext(id: contextID, error: nil); return
        }
        ctx.peer = target

        switch payload {
        case .text(let content):
            // 发文本 → 等 200ms 让对方读完缓冲 → 关
            let msg = TextMessage(
                id: UUID().uuidString.lowercased(),
                content: content,
                ts: Int64(Date().timeIntervalSince1970)
            )
            do {
                let textBody = try MessageCodec.encode(msg)
                try await ctx.connection.send(type: MessageType.text, body: textBody)
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .completed) }
                try? await Task.sleep(nanoseconds: 200_000_000)
                await ctx.connection.close()
            } catch {
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
                await closeContext(id: contextID, error: error)
            }

        case .clipboard(let content, let kind):
            // 发 CLIPBOARD → 等 200ms 让对方读完缓冲 → 关。无 history 记录。
            let msg = ClipboardMessage(
                id: UUID().uuidString.lowercased(),
                content: content,
                kind: kind,
                ts: Int64(Date().timeIntervalSince1970)
            )
            do {
                let clipBody = try MessageCodec.encode(msg)
                try await ctx.connection.send(type: MessageType.clipboard, body: clipBody)
                try? await Task.sleep(nanoseconds: 200_000_000)
                await ctx.connection.close()
            } catch {
                await closeContext(id: contextID, error: error)
            }

        case .file(let sourceURL, let fileSize, let sha256, _):
            // 发 FILE_OFFER → 等 FILE_ACCEPT
            let fileName = sourceURL.lastPathComponent
            let transferID = ctx.transferID ?? UUID()
            ctx.transferID = transferID
            let media = Self.filePreviewMetadata(for: sourceURL)
            let offer = FileOfferMessage(
                transfer_id: transferID.uuidString,
                files: [FileMeta(index: 0,
                                 name: fileName,
                                 size: fileSize,
                                 sha256: sha256,
                                 mime: media.mime,
                                 preview_b64: media.previewBase64)]
            )
            do {
                let offerBody = try MessageCodec.encode(offer)
                try await ctx.connection.send(type: MessageType.fileOffer, body: offerBody)
                ctx.state = .awaitingFileAccept
            } catch {
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
                await closeContext(id: contextID, error: error)
            }
        }
    }

    // MARK: - 文件发送：开始流式发 chunk

    private func clientStartSending(contextID: UUID, acceptBody: Data) async {
        guard let ctx = contexts[contextID] else { return }
        guard case .client(_, .file(let sourceURL, let fileSize, _, _)) = ctx.role else { return }

        // 解析 FILE_ACCEPT.resume_offset；接收端若有半成品文件会要求从该 offset 起发。
        let resumeOffset: UInt64 = {
            guard let accept = try? MessageCodec.decode(FileAcceptMessage.self, from: acceptBody) else { return 0 }
            // 防御：对端不应给出 > fileSize 的 offset
            return min(accept.resume_offset, fileSize)
        }()

        do {
            let handle = try FileHandle(forReadingFrom: sourceURL)
            if resumeOffset > 0 {
                try handle.seek(toOffset: resumeOffset)
                log.info("resume send from offset=\(resumeOffset)/\(fileSize)")
            }
            ctx.fileHandle = handle
            ctx.sentBytes = resumeOffset
            ctx.state = .sendingFile
            if let hid = ctx.historyID {
                updateHistoryStatus(hid, status: .transferring(bytesDone: resumeOffset, bytesTotal: fileSize))
            }
            // 异步流式发送
            Task { await streamChunks(contextID: contextID) }
        } catch {
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
            await closeContext(id: contextID, error: error)
        }
    }

    private func streamChunks(contextID: UUID) async {
        guard let ctx = contexts[contextID],
              let handle = ctx.fileHandle,
              let transferID = ctx.transferID else { return }
        let fileSize = ctx.fileSize
        let chunkSize = 256 * 1024

        while ctx.sentBytes < fileSize {
            if ctx.state.isClosed { return }
            let remaining = fileSize - ctx.sentBytes
            let toRead = Int(min(UInt64(chunkSize), remaining))
            let offset = ctx.sentBytes

            // 磁盘读取 + FILE_CHUNK 编码移出 MainActor（detached），避免大文件传输周期性卡 UI 线程。
            // MainActor 只保留进度 / 状态更新。
            let body: Data? = await Task.detached(priority: .userInitiated) {
                let data = handle.readData(ofLength: toRead)
                if data.isEmpty { return nil }
                let header = FileChunkHeader(transferID: transferID, index: 0, offset: offset)
                return FileChunkHeader.encode(header, data: data)
            }.value
            guard let body, body.count > FileChunkHeader.size else { break }
            let dataCount = body.count - FileChunkHeader.size

            do {
                try await ctx.connection.send(type: MessageType.fileChunk, body: body)
            } catch {
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
                await closeContext(id: contextID, error: error)
                return
            }
            ctx.sentBytes += UInt64(dataCount)
            recordProgress(ctx: ctx, currentBytes: ctx.sentBytes, totalBytes: fileSize)
            if let hid = ctx.historyID {
                updateHistoryStatus(hid, status: .transferring(bytesDone: ctx.sentBytes, bytesTotal: fileSize))
            }
        }
        try? handle.close()
        ctx.fileHandle = nil
        // 等对方 FILE_COMPLETE
    }

    // MARK: - 接收

    private func handleReceivedText(body: Data, contextID: UUID) {
        guard let ctx = contexts[contextID],
              let peer = ctx.peer,
              let text = try? MessageCodec.decode(TextMessage.self, from: body) else { return }
        // 重放去重：同一 (peer, message id) 5 分钟内重复出现即丢弃（security.md §重放）。
        guard registerSeenMessage(peerFingerprint: peer.fingerprint, messageID: text.id) else {
            log.info("drop replayed TEXT id=\(text.id, privacy: .public)")
            return
        }
        let item = HistoryItem(
            peer: peer,
            direction: .incoming,
            kind: .text(text.content),
            status: .completed
        )
        history.insert(item, at: 0)
        unreadByPeer[peer.id, default: 0] += 1
    }

    private func handleReceivedClipboard(body: Data, contextID: UUID) {
        guard let ctx = contexts[contextID],
              let peer = ctx.peer,
              let msg = try? MessageCodec.decode(ClipboardMessage.self, from: body),
              !msg.content.isEmpty else { return }
        guard registerSeenMessage(peerFingerprint: peer.fingerprint, messageID: msg.id) else {
            log.info("drop replayed CLIPBOARD id=\(msg.id, privacy: .public)")
            return
        }
        let entry = ClipboardEntry(
            peerName: peer.name,
            content: msg.content,
            kind: msg.kind,
            receivedAt: Date()
        )
        clipboardInbox.insert(entry, at: 0)
        // 上限 50 条，超出丢最旧。
        if clipboardInbox.count > 50 { clipboardInbox.removeLast(clipboardInbox.count - 50) }
    }

    private func handleReceivedFileOffer(body: Data, contextID: UUID) {
        guard let ctx = contexts[contextID],
              let peer = ctx.peer,
              let offer = try? MessageCodec.decode(FileOfferMessage.self, from: body),
              let first = offer.files.first,
              let transferUUID = UUID(uuidString: offer.transfer_id) else { return }

        // 重放去重 + transfer 归属：同一 transfer_id 5 分钟内重复 / 跨连接复用即丢弃。
        guard registerSeenMessage(peerFingerprint: peer.fingerprint, messageID: offer.transfer_id),
              claimTransfer(transferUUID, ctxID: contextID) else {
            log.info("drop replayed/duplicate FILE_OFFER transfer_id=\(offer.transfer_id, privacy: .public)")
            return
        }

        // 多文件 offer：本实现一条连接只接收 index 0；对其余 index 显式发 FILE_REJECT(unsupported)，
        // 避免发送端无限等待这些 index 的 ACCEPT/REJECT（协议互通要求逐个应答）。
        if offer.files.count > 1 {
            let extraIndices = offer.files.map(\.index).filter { $0 != first.index }
            Task {
                for idx in extraIndices {
                    let body = try? MessageCodec.encode(FileRejectMessage(
                        transfer_id: offer.transfer_id,
                        index: idx,
                        reason: "unsupported_multifile"
                    ))
                    if let body {
                        try? await ctx.connection.send(type: MessageType.fileReject, body: body)
                    }
                }
            }
        }

        // 先查 ResumeStore 是否有匹配的中断进度。匹配键 = (peerFingerprint, sha256)。
        // 命中且本地半成品文件仍在、大小一致、未完成 → 自动接受并发 resume_offset > 0；
        // 不命中 → 走正常用户审批流程。
        Task { @MainActor in
            let resume = await self.resumeStore.find(
                peerFingerprint: peer.fingerprint,
                sha256: first.sha256
            )
            let canResume: Bool = {
                guard let r = resume else { return false }
                guard r.fileSize == first.size, r.bytesDone < first.size else { return false }
                return FileManager.default.fileExists(atPath: r.savedPath)
            }()

            guard let ctx = self.contexts[contextID] else { return }
            if canResume, let r = resume {
                self.startAutoResumeReceive(
                    contextID: contextID,
                    ctx: ctx,
                    peer: peer,
                    transferID: transferUUID,
                    fileMeta: first,
                    record: r
                )
            } else {
                let pending = PendingFileOffer(
                    id: transferUUID,
                    peer: peer,
                    fileName: first.name,
                    fileSize: first.size,
                    sha256: first.sha256,
                    mime: first.mime,
                    previewBase64: first.preview_b64
                )
                ctx.pendingOfferID = pending.id
                self.pendingFileOffers.append(pending)
                // 设置开启且对端已信任 → 自动接受（复用标准接受流程，会把该项移出 pending）。
                if self.autoAcceptFromTrusted, await self.trustStore.isTrusted(peer.fingerprint) {
                    self.respondToFileOffer(pending.id, accept: true)
                }
            }
        }
    }

    /// 命中 ResumeStore：复用 savedURL，append-write 模式开 handle，发 FILE_ACCEPT 带 resume_offset。
    /// 不弹用户审批 sheet — 用户在首次发起时已经同意过该 transfer。
    private func startAutoResumeReceive(
        contextID: UUID,
        ctx: ConnectionContext,
        peer: Device,
        transferID: UUID,
        fileMeta: FileMeta,
        record: ResumeRecord
    ) {
        let savedURL = URL(fileURLWithPath: record.savedPath)
        do {
            let handle = try FileHandle(forWritingTo: savedURL)
            try handle.seek(toOffset: record.bytesDone)
            try handle.truncate(atOffset: record.bytesDone)
            ctx.fileHandle = handle
            ctx.savedURL = savedURL
            ctx.fileSize = fileMeta.size
            ctx.expectedSHA256 = fileMeta.sha256
            ctx.transferID = transferID
            ctx.pendingOfferID = nil
            ctx.receivedBytes = record.bytesDone
            ctx.lastPersistedBytes = record.bytesDone
            ctx.state = .receivingFile

            let item = HistoryItem(
                peer: peer,
                direction: .incoming,
                kind: .file(name: fileMeta.name, size: fileMeta.size, url: savedURL),
                status: .transferring(bytesDone: record.bytesDone, bytesTotal: fileMeta.size)
            )
            history.insert(item, at: 0)
            ctx.historyID = item.id

            Task {
                let body = try? MessageCodec.encode(FileAcceptMessage(
                    transfer_id: transferID.uuidString,
                    index: 0,
                    resume_offset: record.bytesDone
                ))
                if let body {
                    try? await ctx.connection.send(type: MessageType.fileAccept, body: body)
                }
                log.info("auto-resume: \(record.fileName, privacy: .public) from \(record.bytesDone)/\(fileMeta.size)")
            }
        } catch {
            log.error("auto-resume open failed: \(error.localizedDescription)")
            // 回退：丢弃残留记录，走正常审批流程
            Task { await self.resumeStore.clear(peerFingerprint: peer.fingerprint, sha256: fileMeta.sha256) }
            let pending = PendingFileOffer(
                id: transferID,
                peer: peer,
                fileName: fileMeta.name,
                fileSize: fileMeta.size,
                sha256: fileMeta.sha256,
                mime: fileMeta.mime,
                previewBase64: fileMeta.preview_b64
            )
            ctx.pendingOfferID = pending.id
            pendingFileOffers.append(pending)
        }
    }

    private func handleReceivedChunk(body: Data, contextID: UUID) async {
        guard let ctx = contexts[contextID],
              let handle = ctx.fileHandle,
              let (header, payload) = FileChunkHeader.decode(body) else { return }

        // 单帧 data 硬上限 4 MiB（messages.md）：超限视为协议错误关连接。
        if payload.count > Self.maxChunkBytes {
            log.error("FILE_CHUNK over 4MiB (\(payload.count)); closing")
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(L10n.failChunkTooLarge)) }
            await closeContext(id: contextID, error: nil)
            return
        }

        // offset 校验（messages.md）：正常顺序写时 header.offset 应 == 已收字节；
        // 不等说明乱序 / 重复 / resume 起点不一致 → seek 到 header.offset 再写，避免错位累积。
        if header.offset != ctx.receivedBytes {
            do {
                try handle.seek(toOffset: header.offset)
                ctx.receivedBytes = header.offset
                log.info("FILE_CHUNK out-of-order: seek to offset=\(header.offset)")
            } catch {
                if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
                await closeContext(id: contextID, error: error)
                return
            }
        }

        do {
            try handle.write(contentsOf: payload)
        } catch {
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .failed(error.localizedDescription)) }
            await closeContext(id: contextID, error: error)
            return
        }
        ctx.receivedBytes += UInt64(payload.count)
        recordProgress(ctx: ctx, currentBytes: ctx.receivedBytes, totalBytes: ctx.fileSize)
        if let hid = ctx.historyID {
            updateHistoryStatus(hid, status: .transferring(bytesDone: ctx.receivedBytes, bytesTotal: ctx.fileSize))
        }

        // 增量持久化：每写满 resumePersistInterval 字节刷一次 ResumeStore。
        if ctx.receivedBytes - ctx.lastPersistedBytes >= Self.resumePersistInterval,
           ctx.receivedBytes < ctx.fileSize,
           let saved = ctx.savedURL,
           let expected = ctx.expectedSHA256,
           let tid = ctx.transferID,
           let peer = ctx.peer {
            ctx.lastPersistedBytes = ctx.receivedBytes
            let record = ResumeRecord(
                peerFingerprint: peer.fingerprint,
                transferID: tid,
                fileName: saved.lastPathComponent,
                fileSize: ctx.fileSize,
                sha256: expected,
                savedPath: saved.path,
                bytesDone: ctx.receivedBytes,
                updatedAt: Date()
            )
            Task { await self.resumeStore.upsert(record) }
        }

        if ctx.receivedBytes >= ctx.fileSize {
            try? handle.close()
            ctx.fileHandle = nil
            // 校验 sha256
            if let saved = ctx.savedURL, let expected = ctx.expectedSHA256 {
                let actual = (try? Self.sha256OfFile(at: saved)) ?? ""
                if actual != expected {
                    if let hid = ctx.historyID {
                        updateHistoryStatus(hid, status: .failed(L10n.failChecksum))
                    }
                    try? FileManager.default.removeItem(at: saved)
                    if let peer = ctx.peer {
                        await resumeStore.clear(peerFingerprint: peer.fingerprint, sha256: expected)
                    }
                    await closeContext(id: contextID, error: nil)
                    return
                }
                // 完成 → 清掉 ResumeStore 中对应记录
                if let peer = ctx.peer {
                    await resumeStore.clear(peerFingerprint: peer.fingerprint, sha256: expected)
                }
            }
            // 发 FILE_COMPLETE
            if let tid = ctx.transferID {
                let complete = FileCompleteMessage(transfer_id: tid.uuidString, index: 0)
                if let cbody = try? MessageCodec.encode(complete) {
                    try? await ctx.connection.send(type: MessageType.fileComplete, body: cbody)
                }
            }
            if let hid = ctx.historyID { updateHistoryStatus(hid, status: .completed) }
            try? await Task.sleep(nanoseconds: 150_000_000)
            await closeContext(id: contextID, error: nil)
        }
    }

    // MARK: - 关闭与辅助

    private func closeContext(id: UUID, error: Error?) async {
        guard let ctx = contexts.removeValue(forKey: id) else { return }
        // 释放本连接占用的 transfer_id 归属，允许后续合法连接复用该 id。
        transferOwners = transferOwners.filter { $0.value != id }
        if case .awaitingPairApproval(let req) = ctx.state {
            pendingPairings.removeAll { $0.id == req.id }
        }
        if let pid = ctx.pendingOfferID {
            pendingFileOffers.removeAll { $0.id == pid }
        }
        // 接收态被异常关闭（fileHandle 仍持有 + 字节未收齐）→ 视为「连接中断」：
        //   1) 刷一次最新 receivedBytes 到 ResumeStore（自上次定期持久化以来可能又写了几 chunks）
        //   2) history 状态标「连接中断 · 等待续传」
        // ResumeRecord 不在这里删 —— 等下次 FILE_OFFER 来时按 sha256 命中再用。
        if case .receivingFile = ctx.state,
           ctx.fileHandle != nil,
           ctx.receivedBytes < ctx.fileSize {
            if let saved = ctx.savedURL,
               let expected = ctx.expectedSHA256,
               let tid = ctx.transferID,
               let peer = ctx.peer,
               ctx.receivedBytes > 0,
               ctx.receivedBytes > ctx.lastPersistedBytes {
                let record = ResumeRecord(
                    peerFingerprint: peer.fingerprint,
                    transferID: tid,
                    fileName: saved.lastPathComponent,
                    fileSize: ctx.fileSize,
                    sha256: expected,
                    savedPath: saved.path,
                    bytesDone: ctx.receivedBytes,
                    updatedAt: Date()
                )
                await resumeStore.upsert(record)
            }
            if let hid = ctx.historyID {
                updateHistoryStatus(hid, status: .failed(L10n.failDisconnectedResumable))
            }
        } else if case .sendingFile = ctx.state,
                  ctx.sentBytes < ctx.fileSize,
                  let hid = ctx.historyID {
            // 发送态意外断开 — 让 UI 显示失败，用户可从历史重新发起。
            updateHistoryStatus(hid, status: .failed(L10n.failDisconnected))
        }
        // 释放 security scope
        if case .client(_, .file(let url, _, _, let needsAccess)) = ctx.role, needsAccess {
            url.stopAccessingSecurityScopedResource()
        }
        try? ctx.fileHandle?.close()
        ctx.fileHandle = nil
        ctx.state = .closed
        await ctx.connection.close()
        if let error {
            log.debug("ctx \(id) closed with error: \(error.localizedDescription)")
        }
    }

    /// 每秒一次：把进行中传输的瞬时速率按方向汇总成一个时间桶，推入环形序列。
    private func sampleThroughput() {
        var up = 0.0
        var down = 0.0
        for item in history {
            guard case .transferring = item.status, let m = transferMetrics[item.id] else { continue }
            switch item.direction {
            case .outgoing: up += m.bytesPerSec
            case .incoming: down += m.bytesPerSec
            }
        }
        var s = sessionThroughput
        s.up.append(up)
        s.down.append(down)
        let cap = Self.throughputBuckets
        if s.up.count > cap { s.up.removeFirst(s.up.count - cap) }
        if s.down.count > cap { s.down.removeFirst(s.down.count - cap) }
        sessionThroughput = s
    }

    private func updateHistoryStatus(_ id: UUID, status: TransferStatus) {
        if let idx = history.firstIndex(where: { $0.id == id }) {
            history[idx].status = status
        }
        if status.isTerminal {
            transferMetrics.removeValue(forKey: id)
        }
    }

    /// 在 ctx 累计字节变化时调一下，刷新 EMA 字节/秒 + ETA 到 `transferMetrics[historyID]`。
    /// `currentBytes` 是当前累计字节，`totalBytes` 用于算 ETA；同一帧再次进入会被 0.1s 节流。
    private func recordProgress(ctx: ConnectionContext, currentBytes: UInt64, totalBytes: UInt64) {
        guard let hid = ctx.historyID else { return }
        let now = Date()
        let prev = ctx.lastSampleTime
        let prevBytes = ctx.lastSampleBytes
        let dt = prev.map { now.timeIntervalSince($0) } ?? 0
        // 节流：相邻样本至少 100ms，否则会被网络层 chunk 触发频率抖到无意义
        if let _ = prev, dt < 0.1 { return }

        if let _ = prev, dt > 0, currentBytes >= prevBytes {
            let inst = Double(currentBytes - prevBytes) / dt
            // EMA(α=0.3)；首次直接取瞬时值避免起步阶段慢回升
            ctx.emaBytesPerSec = ctx.emaBytesPerSec == 0
                ? inst
                : 0.3 * inst + 0.7 * ctx.emaBytesPerSec
        }
        ctx.lastSampleTime = now
        ctx.lastSampleBytes = currentBytes

        let bps = ctx.emaBytesPerSec
        let eta: Double? = {
            guard bps > 1, totalBytes > currentBytes else { return nil }
            return Double(totalBytes - currentBytes) / bps
        }()
        transferMetrics[hid] = TransferMetrics(bytesPerSec: bps, etaSeconds: eta)
    }

    private func refreshTrusted() async {
        let snap = await trustStore.snapshot()
        await MainActor.run { self.trusted = snap }
    }

    // MARK: - 重放去重 / transfer 归属

    /// 5 分钟窗口去重：首次见到 (peerFP, messageID) 返回 true 并记录；窗口内重复返回 false。
    /// 顺带清理过期条目，避免无限增长。
    private func registerSeenMessage(peerFingerprint: String, messageID: String) -> Bool {
        let now = Date()
        // 清理过期
        seenMessages = seenMessages.filter { now.timeIntervalSince($0.value) < Self.replayWindow }
        let key = "\(peerFingerprint)|\(messageID)"
        if let first = seenMessages[key], now.timeIntervalSince(first) < Self.replayWindow {
            return false
        }
        seenMessages[key] = now
        return true
    }

    /// 校验 transfer_id 未被别的连接占用；首次见即登记到本 ctx。返回 false 表示跨连接复用，应拒绝。
    private func claimTransfer(_ transferID: UUID, ctxID: UUID) -> Bool {
        if let owner = transferOwners[transferID], owner != ctxID {
            return false
        }
        transferOwners[transferID] = ctxID
        return true
    }

    // MARK: - 连接健康巡检（握手超时 + 心跳）

    private func tickConnectionHealth() async {
        let now = Date()
        var toClose: [UUID] = []
        var toPing: [UUID] = []

        for (id, ctx) in contexts {
            switch ctx.state {
            // 纯机器协商态：秒级应完成，超 handshakeTimeout 即回收
            case .awaitingHello, .awaitingHelloAck:
                if now.timeIntervalSince(ctx.createdAt) > Self.handshakeTimeout {
                    toClose.append(id)
                }
            // 人为决策态（等用户点信任/接收）：给宽松窗口，仅兜底回收长期无人理会的僵尸连接
            case .awaitingPairApproval, .awaitingFileAccept:
                if now.timeIntervalSince(ctx.createdAt) > Self.decisionTimeout {
                    toClose.append(id)
                }
            // 业务态：超过一个心跳周期没收到任何帧就 PING；连续丢 PONG 判死
            case .ready, .receivingFile, .sendingFile:
                if now.timeIntervalSince(ctx.lastInboundAt) > Self.heartbeatInterval {
                    if ctx.missedPongs >= Self.maxMissedPongs {
                        toClose.append(id)
                    } else {
                        ctx.missedPongs += 1
                        toPing.append(id)
                    }
                }
            case .closed:
                break
            }
        }

        for id in toPing {
            guard let ctx = contexts[id] else { continue }
            try? await ctx.connection.send(type: MessageType.ping, body: Data("{}".utf8))
        }
        for id in toClose {
            log.info("connection health: closing ctx \(id.uuidString) (handshake timeout / missed pongs)")
            await closeContext(id: id, error: nil)
        }
    }

    // MARK: - SHA256 + 路径辅助

    nonisolated static func sha256OfFile(at url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let chunk = handle.readData(ofLength: 1024 * 1024)
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func defaultSaveDir(for peer: Device) -> URL {
        let fm = FileManager.default
        let documents = (try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let dir = documents
            .appendingPathComponent("MeshDrop", isDirectory: true)
            .appendingPathComponent(peer.name.isEmpty ? peer.id : peer.name, isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func uniqueFileURL(in dir: URL, fileName: String) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent(fileName)
        if !fm.fileExists(atPath: candidate.path) { return candidate }
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        var n = 1
        while true {
            let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            candidate = dir.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    nonisolated private static func filePreviewMetadata(for url: URL) -> (mime: String?, previewBase64: String?) {
        let ext = url.pathExtension
        let type = ext.isEmpty ? nil : UTType(filenameExtension: ext)
        let mime = type?.preferredMIMEType
        guard type?.conforms(to: .image) == true,
              let preview = makeImagePreviewBase64(url: url) else {
            return (mime, nil)
        }
        return (mime, preview)
    }

    nonisolated private static func makeImagePreviewBase64(url: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 480
        ]
        guard let thumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.72]
        CGImageDestinationAddImage(destination, thumb, props as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return (data as Data).base64EncodedString()
    }

    // MARK: - 平台默认信息

    private static func defaultDisplayName() -> String {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return UIDeviceWrapper.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "MeshDrop"
        #endif
    }

    private static func systemModel() -> String? {
        #if os(macOS)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        return String(cString: buf)
        #elseif os(iOS) || os(tvOS) || os(visionOS)
        var sys = utsname()
        uname(&sys)
        return withUnsafePointer(to: &sys.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
                String(cString: $0)
            }
        }
        #else
        return nil
        #endif
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit
private enum UIDeviceWrapper {
    static var name: String { UIDevice.current.name }
}
#endif

// MARK: - ConnectionContext

@MainActor
final class ConnectionContext {
    enum Role {
        case server
        case client(target: Device, payload: ClientPayload)
    }

    enum ClientPayload {
        case text(String)
        case clipboard(content: String, kind: String)
        case file(sourceURL: URL, fileSize: UInt64, sha256: String, needsSecurityScope: Bool)
    }

    enum State {
        case awaitingHello
        case awaitingPairApproval(PairingRequest)
        case awaitingHelloAck
        case awaitingFileAccept
        case sendingFile
        case ready
        case receivingFile
        case closed

        var isClosed: Bool {
            if case .closed = self { return true }; return false
        }
    }

    let id: UUID = UUID()
    let connection: Connection
    let role: Role
    var state: State
    var peer: Device?

    /// ctx 创建时刻：握手超时判定基准。
    let createdAt: Date = Date()
    /// 心跳：自上次收到对端任意帧的时刻；连续丢 PONG 计数。
    var lastInboundAt: Date = Date()
    var missedPongs: Int = 0

    // 关联的历史记录与传输
    var historyID: UUID?
    var transferID: UUID?
    var pendingOfferID: UUID?

    // 文件 I/O
    var fileHandle: FileHandle?
    var fileSize: UInt64 = 0
    var sentBytes: UInt64 = 0
    var receivedBytes: UInt64 = 0
    var savedURL: URL?
    var expectedSHA256: String?
    /// 接收方：上次写入 ResumeStore 的 bytesDone，用来限制持久化频率。
    var lastPersistedBytes: UInt64 = 0

    // 速率窗口：上次采样时刻 + 当时的累计字节，用来算 Δbytes / Δtime。
    var lastSampleTime: Date?
    var lastSampleBytes: UInt64 = 0
    /// 指数移动平均字节/秒（α=0.3，足够平滑但不会僵硬滞后）。
    var emaBytesPerSec: Double = 0

    init(connection: Connection, role: Role, state: State) {
        self.connection = connection
        self.role = role
        self.state = state
    }
}
