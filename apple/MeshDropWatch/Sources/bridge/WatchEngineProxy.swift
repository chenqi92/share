import Foundation
import Combine
import OSLog

/// Watch 端的 "Engine 代理"。API 形状对齐 [ShareEngine]（iPhone 端 / Mac 端的真 Engine），
/// 让 UI 切换时只改类型即可，不感知底层是 LAN 直连还是 WatchConnectivity 中转。
///
/// 重要：watch 上**没有** LAN，所有 `devices` / `history` / `pendingOffers` 都是 iPhone 桥接侧
/// 通过事件推过来的快照。如果 `isOnline == false`（companion 不在身边），UI 应进入 OFFLINE 态，
/// 禁用所有发送 CTA。
@MainActor
final class WatchEngineProxy: ObservableObject {

    static let shared = WatchEngineProxy()

    // MARK: - Published 状态（UI 绑定）

    /// 桥接通道是否可达（companion iPhone 在身边）。**不是** LAN 状态——LAN 状态 watch 不感知。
    @Published private(set) var isOnline: Bool = false {
        didSet { publishComplicationSnapshot() }
    }

    /// 当前 bridge 是否在初始化（activation 中 / 第一次同步快照中）。
    @Published private(set) var isStarting: Bool = false

    /// 最近一次错误（命令超时 / 网络异常 / activation 失败）。
    @Published var lastError: String?

    /// LAN 设备清单（iPhone 桥接侧来的）。
    @Published private(set) var devices: [BridgeDevice] = [] {
        didSet { publishComplicationSnapshot() }
    }

    /// 历史（双向）。
    @Published private(set) var history: [BridgeHistoryItem] = []

    /// 待审 incoming file offer。
    @Published private(set) var pendingOffers: [BridgeOffer] = []

    /// 待审配对请求。
    @Published private(set) var pendingPairings: [BridgePairing] = []

    /// 进行中的 transfer（key = id）。
    @Published private(set) var transfers: [String: BridgeTransferProgress] = [:]

    /// 收件箱：iPhone 中转来的真实入站内容（文本内联 / 文件已落盘）。最新在前。
    @Published private(set) var inbox: [BridgeInboxItem] = []

    // MARK: - 内部

    private let client = WatchSessionClient()
    private let log = Logger(subsystem: "com.welape.meshdrop", category: "WatchEngineProxy")
    private var didStart = false

    /// transferFile 先于事件到达时，暂存 ref → 本地落盘 URL，待事件来时关联。
    private var pendingFileRefs: [String: URL] = [:]

    private init() {}

    // MARK: - 生命周期

    func start() {
        guard !didStart else { return }
        didStart = true
        isStarting = true

        client.onReachabilityChanged = { [weak self] reachable in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isOnline = reachable
                if reachable {
                    self.lastError = nil
                    await self.requestSnapshot()
                }
            }
        }

        client.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.apply(event)
            }
        }

        // iPhone transferFile 送来的入站文件落盘完成 → 关联到收件项。
        client.onFileReceived = { [weak self] ref, localURL in
            Task { @MainActor [weak self] in
                self?.attachReceivedFile(ref: ref, localURL: localURL)
            }
        }

        client.onActivationCompleted = { [weak self] ok, err in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isStarting = false
                if let err {
                    self.lastError = "桥接初始化失败：\(err)"
                }
                if ok {
                    await self.requestSnapshot()
                }
            }
        }

        client.start()
    }

    // MARK: - 命令（对齐 ShareEngine）

    /// 发文本。
    func sendText(to peerId: String, text: String) async throws {
        let cmd = BridgeCommand(
            type: .sendText,
            payload: [
                "peerId": AnyCodable(peerId),
                "text": AnyCodable(text),
            ]
        )
        try await dispatch(cmd)
    }

    /// 发文件：watch 先 `transferFile`（metadata 带裸 ref token），文件入队后再发 `send_file_ref`
    /// 命令，`payload.fileRef` = 同一 ref；iPhone 凭 ref 取落盘文件 + peerId 走 LAN 代发。
    /// 见 companion-bridges.md §4.1。
    func sendFileRef(to peerId: String, fileURL: URL, name: String) async throws {
        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: fileURL.path))
            .flatMap { ($0[.size] as? NSNumber)?.int64Value }
        let ref = try client.transferFile(at: fileURL, peerId: peerId, name: name)
        var payload: [String: AnyCodable] = [
            "peerId": AnyCodable(peerId),
            "fileRef": AnyCodable(ref),
            "name": AnyCodable(name),
        ]
        if let sizeBytes { payload["sizeBytes"] = AnyCodable(sizeBytes) }
        let cmd = BridgeCommand(type: .sendFileRef, payload: payload)
        try await dispatch(cmd)
    }

    func acceptOffer(_ offerId: String) async throws {
        let cmd = BridgeCommand(type: .acceptOffer, payload: ["offerId": AnyCodable(offerId)])
        try await dispatch(cmd)
        pendingOffers.removeAll { $0.id == offerId }
    }

    func rejectOffer(_ offerId: String) async throws {
        let cmd = BridgeCommand(type: .rejectOffer, payload: ["offerId": AnyCodable(offerId)])
        try await dispatch(cmd)
        pendingOffers.removeAll { $0.id == offerId }
    }

    func acceptPairing(_ pairingId: String, trust: Bool) async throws {
        let cmd = BridgeCommand(
            type: .acceptPairing,
            payload: [
                "pairingId": AnyCodable(pairingId),
                "trust": AnyCodable(trust),
            ]
        )
        try await dispatch(cmd)
        pendingPairings.removeAll { $0.id == pairingId }
    }

    func rejectPairing(_ pairingId: String) async throws {
        let cmd = BridgeCommand(type: .rejectPairing, payload: ["pairingId": AnyCodable(pairingId)])
        try await dispatch(cmd)
        pendingPairings.removeAll { $0.id == pairingId }
    }

    func clearHistory(scope: String = "all") async throws {
        let cmd = BridgeCommand(type: .clearHistory, payload: ["scope": AnyCodable(scope)])
        try await dispatch(cmd)
        history.removeAll()
    }

    func deleteHistoryItem(_ id: String) async throws {
        let cmd = BridgeCommand(type: .deleteHistoryItem, payload: ["itemId": AnyCodable(id)])
        try await dispatch(cmd)
        history.removeAll { $0.id == id }
    }

    // MARK: - 内部派发

    private func dispatch(_ command: BridgeCommand) async throws {
        do {
            let ack = try await client.sendCommand(command)
            if !ack.ok {
                lastError = ack.error ?? "命令失败"
                throw NSError(
                    domain: "WatchEngineProxy", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: lastError ?? "命令失败"]
                )
            }
            lastError = nil
        } catch let e as WatchSessionClient.BridgeError {
            lastError = e.errorDescription
            throw e
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    private func requestSnapshot() async {
        do {
            let ack = try await client.sendCommand(BridgeCommand(type: .getState))
            guard ack.ok, let result = ack.result else { return }
            ingestSnapshot(result)
        } catch {
            // 静默失败：iPhone 端可能还没装 WatchBridge（B02 未合）；
            // UI 仍可保持 OFFLINE 态，等下次 reachability 变化再试。
            log.notice("get_state 失败：\(error.localizedDescription, privacy: .public)")
        }
    }

    private func ingestSnapshot(_ result: [String: AnyCodable]) {
        if let raw = result["devices"]?.value as? [Any?] {
            devices = decodeArray(BridgeDevice.self, from: raw)
        }
        if let raw = result["history"]?.value as? [Any?] {
            history = decodeArray(BridgeHistoryItem.self, from: raw)
        }
        if let raw = result["pendingOffers"]?.value as? [Any?] {
            pendingOffers = decodeArray(BridgeOffer.self, from: raw)
        }
        if let raw = result["pendingPairings"]?.value as? [Any?] {
            pendingPairings = decodeArray(BridgePairing.self, from: raw)
        }
    }

    private func decodeArray<T: Decodable>(_ type: T.Type, from raw: [Any?]) -> [T] {
        raw.compactMap { item -> T? in
            guard let dict = item as? [String: Any] else { return nil }
            return try? BridgeCodec.decode(T.self, from: dict)
        }
    }

    private func apply(_ event: BridgeEvent) {
        let payload = event.payload
        switch event.type {
        case .deviceAdded, .deviceUpdated:
            if let device = try? BridgeCodec.decode(BridgeDevice.self, fromPayload: payload) {
                if let idx = devices.firstIndex(where: { $0.id == device.id }) {
                    devices[idx] = device
                } else {
                    devices.append(device)
                }
            }
        case .deviceRemoved:
            if let id = payload["id"]?.value as? String {
                devices.removeAll { $0.id == id }
            }
        case .pairingPending:
            if let p = try? BridgeCodec.decode(BridgePairing.self, fromPayload: payload) {
                pendingPairings.append(p)
            }
        case .offerPending:
            if let offer = try? BridgeCodec.decode(BridgeOffer.self, fromPayload: payload) {
                pendingOffers.append(offer)
            }
        case .transferProgress:
            if let p = try? BridgeCodec.decode(BridgeTransferProgress.self, fromPayload: payload) {
                transfers[p.id] = p
            }
        case .transferDone:
            if let id = payload["id"]?.value as? String {
                transfers.removeValue(forKey: id)
            }
        case .historyAdded:
            if let item = try? BridgeCodec.decode(BridgeHistoryItem.self, fromPayload: payload) {
                history.insert(item, at: 0)
            }
        case .inboxText, .inboxFileReady:
            ingestInbox(from: payload)
        }
    }

    // MARK: - 收件箱

    /// 从 inbox_text / inbox_file_ready 事件里解出 InboxItem 插入收件箱。
    /// 与其余事件一致：payload 即 InboxItem（FLAT，不嵌子键），见 companion-bridges.md §2/§3。
    private func ingestInbox(from payload: [String: AnyCodable]) {
        guard let item = try? BridgeCodec.decode(BridgeInboxItem.self, fromPayload: payload) else {
            log.error("inbox 事件解析失败")
            return
        }
        var entry = item
        // 文件可能比事件先到（transferFile 完成回调早于 sendMessage）；如已落盘则补上本地路径。
        if entry.kind == "file", let ref = entry.fileRef,
           let url = pendingFileRefs.removeValue(forKey: ref) {
            entry.localPath = url.path
        }
        upsertInbox(entry)
    }

    /// transferFile 落盘回调。若对应收件项事件已到则直接补路径，否则缓存等事件。
    private func attachReceivedFile(ref: String, localURL: URL) {
        if let idx = inbox.firstIndex(where: { $0.fileRef == ref }) {
            inbox[idx].localPath = localURL.path
        } else {
            // 事件还没到，先缓存 ref → 路径。
            pendingFileRefs[ref] = localURL
        }
    }

    private func upsertInbox(_ item: BridgeInboxItem) {
        if let idx = inbox.firstIndex(where: { $0.id == item.id }) {
            // 已存在（如先收到文件占位）→ 合并本地路径。
            var merged = item
            if merged.localPath == nil { merged.localPath = inbox[idx].localPath }
            inbox[idx] = merged
        } else {
            inbox.insert(item, at: 0)
        }
        if inbox.count > 50 { inbox.removeLast(inbox.count - 50) }
    }

    /// UI 用：删除一条收件项（清除本地文件副本）。
    func removeInboxItem(_ id: String) {
        if let item = inbox.first(where: { $0.id == id }), let path = item.localPath {
            try? FileManager.default.removeItem(atPath: path)
        }
        inbox.removeAll { $0.id == id }
    }

    // MARK: - Complication 快照

    /// 把当前 devices / online 写入共享存储，触发表盘 complication 刷新。
    private func publishComplicationSnapshot() {
        ComplicationStore.write(deviceCount: devices.count, isOnline: isOnline)
    }
}
