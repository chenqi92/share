#if canImport(WatchConnectivity)
import Foundation
import Combine
import WatchConnectivity
import MeshDropKit
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "WatchBridge")

/// iPhone 端的 Watch Companion Bridge 服务。
///
/// 职责：
/// - `WCSession.default.activate()`，作为 phone-side delegate
/// - 收到 watch → phone 的 [WatchBridge.Command]：解码 → 转 ShareEngine → 用 replyHandler 回执
/// - 订阅 engine.$devices / $history / $pendingFileOffers / $pendingPairings → 通过
///   `sendMessage(_:replyHandler:nil)` 把 [WatchBridge.Event] 推 watch
/// - 当 watch 断连（`isReachable == false`）30s 仍无回连，停止节流的 progress 事件，
///   只保留控制事件（offer / pairing / done）
///
/// 注意：这里不直接连 LAN —— LAN 流量永远走 ShareEngine。
@MainActor
final class WatchSessionController: NSObject, ObservableObject {
    static let shared = WatchSessionController()

    private weak var engine: ShareEngine?
    private var subs: Set<AnyCancellable> = []
    private var lastReachableAt: Date = .distantPast
    private var hasStarted = false

    /// 离线判定窗口：reachable 持续 false 超过此值，认为 watch 暂时不可达。
    static let offlineWindow: TimeInterval = 30

    func start(engine: ShareEngine) {
        guard !hasStarted else { return }
        hasStarted = true
        self.engine = engine

        guard WCSession.isSupported() else {
            log.info("WCSession 不支持（非 iOS 真机），WatchBridge 跳过")
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        log.info("WCSession activate 请求已发出")

        subscribe(to: engine)
    }

    // MARK: - 订阅 engine 状态变化 → 推 watch 事件

    private func subscribe(to engine: ShareEngine) {
        // device 列表变化：发送 device_added / device_updated / device_removed
        var lastDevices: [String: [String: Any]] = [:]
        engine.$devices
            .sink { [weak self] devices in
                guard let self else { return }
                var next: [String: [String: Any]] = [:]
                for d in devices { next[d.id] = Self.deviceDTO(from: d) }
                // added / updated
                for (id, dto) in next {
                    if let prev = lastDevices[id] {
                        if !Self.dictEqual(prev, dto) {
                            self.sendEvent(type: .deviceUpdated, payload: dto)
                        }
                    } else {
                        self.sendEvent(type: .deviceAdded, payload: dto)
                    }
                }
                // removed
                for id in lastDevices.keys where next[id] == nil {
                    self.sendEvent(type: .deviceRemoved, payload: ["id": id])
                }
                lastDevices = next
            }
            .store(in: &subs)

        // pendingPairings: 新增推 pairing_pending
        var seenPairings: Set<UUID> = []
        engine.$pendingPairings
            .sink { [weak self] reqs in
                guard let self else { return }
                for req in reqs where !seenPairings.contains(req.id) {
                    seenPairings.insert(req.id)
                    self.sendEvent(type: .pairingPending, payload: Self.pairingDTO(from: req))
                }
            }
            .store(in: &subs)

        // pendingFileOffers: 新增推 offer_pending
        var seenOffers: Set<UUID> = []
        engine.$pendingFileOffers
            .sink { [weak self] offers in
                guard let self else { return }
                for offer in offers where !seenOffers.contains(offer.id) {
                    seenOffers.insert(offer.id)
                    self.sendEvent(type: .offerPending, payload: Self.offerDTO(from: offer))
                }
            }
            .store(in: &subs)

        // history: 新增推 history_added，transferring 项节流推 transfer_progress / transfer_done
        var seenHistory: Set<UUID> = []
        var lastProgressAt: [UUID: Date] = [:]
        // 已转发到 watch 的入站收件项（避免 history 多次发布时重复推 / 重复传文件）。
        var forwardedInbox: Set<UUID> = []
        engine.$history
            .sink { [weak self] items in
                guard let self else { return }
                for item in items {
                    if !seenHistory.contains(item.id) {
                        seenHistory.insert(item.id)
                        self.sendEvent(type: .historyAdded, payload: Self.historyDTO(from: item))
                    }
                    switch item.status {
                    case .transferring(let done, let total):
                        // 节流：≥ 200ms / 帧
                        let now = Date()
                        if let last = lastProgressAt[item.id],
                           now.timeIntervalSince(last) < 0.2 { continue }
                        lastProgressAt[item.id] = now
                        // watch 离线时不发节流事件
                        guard self.isWatchReachable() else { continue }
                        self.sendEvent(type: .transferProgress, payload: [
                            "id": item.id.uuidString,
                            "bytesSent": Int64(done),
                            "totalBytes": Int64(total),
                        ])
                    case .completed:
                        self.sendEvent(type: .transferDone, payload: [
                            "id": item.id.uuidString, "ok": true,
                        ])
                        // 入站完成的内容中转给 watch（文本内联 / 文件经 transferFile）。
                        if item.direction == .incoming, !forwardedInbox.contains(item.id) {
                            forwardedInbox.insert(item.id)
                            self.forwardIncomingToWatch(item)
                        }
                    case .failed(let msg):
                        self.sendEvent(type: .transferDone, payload: [
                            "id": item.id.uuidString, "ok": false, "error": msg,
                        ])
                    default:
                        break
                    }
                }
            }
            .store(in: &subs)
    }

    // MARK: - 入站内容中转给 watch

    /// 把一条已完成的**入站**历史项推给 watch。
    /// - 文本：内联在 `inbox_text` 事件里（无需文件通道）。
    /// - 文件：先 `transferFile(_:metadata:)` 把文件送过去（即便 watch 当前不 reachable，
    ///   WCSession 也会排队后台传），落盘后 watch 端凭 metadata 的 ref 关联到 `inbox_file_ready`
    ///   事件。事件本身用 sendMessage 推（reachable 时即时；否则 watch 端重连后靠 transferFile
    ///   完成回调兜底，见 WatchSessionClient）。
    private func forwardIncomingToWatch(_ item: HistoryItem) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // inbox_text / inbox_file_ready 的 payload 仍把收件项放在 `inbox` 子键下
        // （watch 端 ingestInbox 读 payload["inbox"]），与其它 FLAT 事件约定不同，这是有意保留。
        switch item.kind {
        case .text(let content):
            let inbox: [String: Any] = [
                "id": item.id.uuidString,
                "peerName": item.peer.name,
                "kind": "text",
                "text": content,
                "receivedAt": Int64(item.createdAt.timeIntervalSince1970),
            ]
            sendEvent(type: .inboxText, payload: ["inbox": inbox])

        case .file(let name, let size, let url):
            guard let fileURL = url, FileManager.default.fileExists(atPath: fileURL.path) else {
                log.error("入站文件 \(name) 无可用 URL，无法中转给 watch")
                return
            }
            // 大文件经 WCSession 很慢；这里设一个保护上限（32 MiB），超过只推元数据不传字节，
            // watch 端展示「请在 iPhone 上查看」。
            let maxWatchFileBytes: UInt64 = 32 * 1024 * 1024
            let ref = item.id.uuidString
            var inbox: [String: Any] = [
                "id": item.id.uuidString,
                "peerName": item.peer.name,
                "kind": "file",
                "fileName": name,
                "sizeBytes": size,
                "receivedAt": Int64(item.createdAt.timeIntervalSince1970),
            ]
            if size <= maxWatchFileBytes {
                inbox["fileRef"] = ref
                let metadata: [String: Any] = [
                    "ref": ref,
                    "kind": "inbox_file",
                    "name": name,
                    "peerName": item.peer.name,
                    "historyId": item.id.uuidString,
                ]
                session.transferFile(fileURL, metadata: metadata)
            }
            sendEvent(type: .inboxFileReady, payload: ["inbox": inbox])
        }
    }

    private func isWatchReachable() -> Bool {
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        if session.isReachable {
            lastReachableAt = Date()
            return true
        }
        // 不 reachable，看是否在 offline window 内
        return Date().timeIntervalSince(lastReachableAt) < Self.offlineWindow
    }

    // MARK: - 推事件（FLAT wire 信封，与 watch 端 BridgeEvent 对齐）

    /// 直接拼 `{v,id,type,ts,payload}` 字典发送。payload 一律 FLAT（DTO 字段平铺到 payload 顶层，
    /// 不再嵌 device/offer/pairing/history 子键），与 watch 端 `BridgeCodec.decode(_, fromPayload:)`
    /// 的解码方式一致。`device_removed`/`transfer_done` 用 `id`（不是 deviceId/transferId）。
    /// 例外：inbox_text / inbox_file_ready 的 payload 仍带 `inbox` 子键。
    private func sendEvent(type: WatchBridge.EventType, payload: [String: Any]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        let dict: [String: Any] = [
            "v": WatchBridge.protocolVersion,
            "id": UUID().uuidString,
            "type": type.rawValue,
            "ts": Int64(Date().timeIntervalSince1970),
            "payload": payload,
        ]
        session.sendMessage(dict, replyHandler: nil) { err in
            log.debug("push event \(type.rawValue) 失败：\(err.localizedDescription)")
        }
    }

    // MARK: - 命令路由（watch → phone）

    /// 命令处理。回执直接拼 `{v,id,ok,error?,result?}` 字典：result 里的 DTO 也走 FLAT 构造，
    /// 与 watch 端 `ingestSnapshot` 的解码（`devices/history/pendingOffers/pendingPairings` →
    /// BridgeDevice/BridgeHistoryItem/BridgeOffer/BridgePairing）对齐。
    fileprivate func handle(command: WatchBridge.Command) async -> [String: Any] {
        guard let engine else {
            return Self.ack(id: command.id, ok: false, error: "engine_not_ready")
        }
        switch command.type {
        case .listDevices:
            return Self.ack(id: command.id, ok: true, result: [
                "devices": engine.devices.map { Self.deviceDTO(from: $0) },
            ])

        case .getState:
            return Self.ack(id: command.id, ok: true, result: [
                "devices": engine.devices.map { Self.deviceDTO(from: $0) },
                "history": engine.history.prefix(50).map { Self.historyDTO(from: $0) },
                "pendingPairings": engine.pendingPairings.map { Self.pairingDTO(from: $0) },
                "pendingOffers": engine.pendingFileOffers.map { Self.offerDTO(from: $0) },
            ])

        case .sendText:
            guard let pid = command.payload?.peerId,
                  let text = command.payload?.text,
                  let peer = engine.devices.first(where: { $0.id == pid }) else {
                return Self.ack(id: command.id, ok: false, error: "peer_or_text_missing")
            }
            engine.sendText(to: peer, content: text)
            return Self.ack(id: command.id, ok: true)

        case .sendFileRef:
            guard let pid = command.payload?.peerId,
                  let ref = command.payload?.fileRef,
                  let peer = engine.devices.first(where: { $0.id == pid }) else {
                return Self.ack(id: command.id, ok: false, error: "peer_or_fileref_missing")
            }
            // watch 在 transferFile 时把文件写到 phone container 的 ref URL（metadata.ref = 裸 token），
            // 这里按约定从 `Library/Caches/com.welape.meshdrop.watchbridge/<ref>` 读取。
            let url = Self.fileRefURL(for: ref)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return Self.ack(id: command.id, ok: false, error: "fileref_not_found")
            }
            engine.sendFile(to: peer, sourceURL: url)
            return Self.ack(id: command.id, ok: true)

        case .acceptOffer:
            guard let oid = command.payload?.offerId, let uuid = UUID(uuidString: oid) else {
                return Self.ack(id: command.id, ok: false, error: "offerId_missing")
            }
            engine.respondToFileOffer(uuid, accept: true)
            return Self.ack(id: command.id, ok: true)

        case .rejectOffer:
            guard let oid = command.payload?.offerId, let uuid = UUID(uuidString: oid) else {
                return Self.ack(id: command.id, ok: false, error: "offerId_missing")
            }
            engine.respondToFileOffer(uuid, accept: false)
            return Self.ack(id: command.id, ok: true)

        case .acceptPairing:
            guard let pid = command.payload?.pairingId, let uuid = UUID(uuidString: pid) else {
                return Self.ack(id: command.id, ok: false, error: "pairingId_missing")
            }
            let trust = command.payload?.trust ?? false
            engine.respondToPairing(uuid, decision: trust ? .trust : .allowOnce)
            return Self.ack(id: command.id, ok: true)

        case .rejectPairing:
            guard let pid = command.payload?.pairingId, let uuid = UUID(uuidString: pid) else {
                return Self.ack(id: command.id, ok: false, error: "pairingId_missing")
            }
            engine.respondToPairing(uuid, decision: .reject)
            return Self.ack(id: command.id, ok: true)

        case .clearHistory:
            engine.clearHistory()
            return Self.ack(id: command.id, ok: true)

        case .deleteHistoryItem:
            guard let iid = command.payload?.itemId, let uuid = UUID(uuidString: iid) else {
                return Self.ack(id: command.id, ok: false, error: "itemId_missing")
            }
            engine.removeHistoryItem(uuid)
            return Self.ack(id: command.id, ok: true)
        }
    }

    // MARK: - 回执 / FLAT DTO 构造（wire schema v=1）

    /// 拼回执字典 `{v,id,ok,error?,result?}`（`id` 同请求）。
    nonisolated static func ack(id: String, ok: Bool,
                                error: String? = nil,
                                result: [String: Any]? = nil) -> [String: Any] {
        var dict: [String: Any] = [
            "v": WatchBridge.protocolVersion,
            "id": id,
            "ok": ok,
        ]
        if let error { dict["error"] = error }
        if let result { dict["result"] = result }
        return dict
    }

    /// Device → FLAT dict（字段集对齐 watch 端 BridgeDevice）。
    /// `ip` / `busy` phone 侧暂无真实来源，给默认值（""/false）。
    nonisolated static func deviceDTO(from device: Device) -> [String: Any] {
        [
            "id": device.id,
            "displayName": device.name,
            "kind": WatchBridge.kindLabel(for: device.os),
            "model": device.model ?? "",
            "ip": "",
            "rttMs": 0,
            "online": true,
            "trusted": false,
            "busy": false,
        ]
    }

    /// PairingRequest → FLAT dict（对齐 BridgePairing）。`code` phone 侧无对应概念，给 ""。
    nonisolated static func pairingDTO(from req: PairingRequest) -> [String: Any] {
        [
            "id": req.id.uuidString,
            "peerName": req.peer.name,
            "code": "",
            "fingerprint": req.peer.humanFingerprint,
            "createdAt": Int64(req.receivedAt.timeIntervalSince1970),
        ]
    }

    /// PendingFileOffer → FLAT dict（对齐 BridgeOffer，单文件包成一元 files[]）。
    nonisolated static func offerDTO(from offer: PendingFileOffer) -> [String: Any] {
        let file: [String: Any] = [
            "name": offer.fileName,
            "sizeBytes": Int64(offer.fileSize),
            "mime": offer.mime ?? "application/octet-stream",
        ]
        return [
            "id": offer.id.uuidString,
            "peerId": offer.peer.id,
            "peerName": offer.peer.name,
            "kind": "file",
            "files": [file],
            "createdAt": Int64(offer.receivedAt.timeIntervalSince1970),
        ]
    }

    /// HistoryItem → FLAT dict（对齐 BridgeHistoryItem，文件项用 files[]）。
    nonisolated static func historyDTO(from item: HistoryItem) -> [String: Any] {
        let direction = (item.direction == .outgoing) ? "sent" : "received"
        let ok: Bool
        if case .completed = item.status { ok = true } else { ok = false }
        var dict: [String: Any] = [
            "id": item.id.uuidString,
            "direction": direction,
            "peerName": item.peer.name,
            "ok": ok,
            "completedAt": Int64(item.createdAt.timeIntervalSince1970),
        ]
        switch item.kind {
        case .text(let content):
            dict["kind"] = "text"
            dict["text"] = content
        case .file(let name, let size, _):
            var bytes: UInt64 = size
            if case .transferring(let done, _) = item.status { bytes = done }
            dict["kind"] = "file"
            dict["files"] = [[
                "name": name,
                "sizeBytes": Int64(size),
                "mime": "application/octet-stream",
            ]]
            dict["bytesTransferred"] = Int64(bytes)
        }
        return dict
    }

    /// 两个 wire dict 是否语义相等（用于 device added vs updated 去抖）。
    nonisolated static func dictEqual(_ a: [String: Any], _ b: [String: Any]) -> Bool {
        guard let da = try? JSONSerialization.data(withJSONObject: a, options: [.sortedKeys]),
              let db = try? JSONSerialization.data(withJSONObject: b, options: [.sortedKeys]) else {
            return false
        }
        return da == db
    }

    // MARK: - file ref 落盘约定

    /// `transferFile(_:metadata:)` 完成后 watch 端把文件放到 phone 的 cache 子目录。
    /// 此函数返回约定的本地路径。
    nonisolated static func fileRefURL(for ref: String) -> URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .cachesDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("com.welape.meshdrop.watchbridge", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(ref)
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionController: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        if let error {
            log.error("WCSession activate 失败：\(error.localizedDescription)")
        } else {
            log.info("WCSession activate 完成 state=\(activationState.rawValue)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        log.debug("WCSession 进入 inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        log.debug("WCSession deactivated，重新 activate")
        WCSession.default.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        log.debug("watch reachable=\(session.isReachable)")
    }

    /// 命令请求 + replyHandler（同步回执）。
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            do {
                let cmd = try WatchBridge.decode(WatchBridge.Command.self, from: message)
                let dict = await Self.shared.handle(command: cmd)
                replyHandler(dict)
            } catch {
                replyHandler([
                    "v": WatchBridge.protocolVersion,
                    "id": (message["id"] as? String) ?? "",
                    "ok": false,
                    "error": "decode_failed: \(error.localizedDescription)"
                ])
            }
        }
    }

    /// 单向事件（无回执，留给 watch 端的客户端事件 — 这边不期待 watch 推什么，写空实现）。
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        log.debug("收到 watch 无回执消息（忽略）：\(message.keys.sorted())")
    }

    /// 大对象通道：watch 端用 transferFile 把文件传到 phone container 后会触发。
    ///
    /// 约定（companion-bridges.md §4.1）：watch 的 metadata 里带
    /// `ref`（裸 token）/`type`/`peerId`/`name`。文件先按 ref 落盘到约定路径；
    /// 若 metadata 已带 `type == send_file_ref` 且有 `peerId`，则直接路由发送
    /// （watch 端 transferFile 后不再单发 send_file_ref 命令，故这里兜底直发）。
    /// 若没带 peerId，则只落盘，等随后的 send_file_ref 命令凭同一 ref 取文件发送。
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let fm = FileManager.default
        let metadata = file.metadata ?? [:]
        let ref = metadata["ref"] as? String ?? UUID().uuidString
        let dst = WatchSessionController.fileRefURL(for: ref)
        do {
            if fm.fileExists(atPath: dst.path) {
                try fm.removeItem(at: dst)
            }
            try fm.moveItem(at: file.fileURL, to: dst)
            log.info("watch 文件落盘 ref=\(ref)")
        } catch {
            log.error("watch 文件移动失败：\(error.localizedDescription)")
            return
        }

        // watch 出站代发：metadata 已带 peerId 时直接路由（不等命令）。
        if (metadata["type"] as? String) == WatchBridge.CommandType.sendFileRef.rawValue,
           let peerId = metadata["peerId"] as? String {
            Task { @MainActor in
                guard let engine = Self.shared.engine,
                      let peer = engine.devices.first(where: { $0.id == peerId }) else {
                    log.error("watch 代发：peerId=\(peerId) 不在当前设备列表，已落盘等命令兜底")
                    return
                }
                engine.sendFile(to: peer, sourceURL: dst)
            }
        }
    }
}

#else

import Foundation
import MeshDropKit

/// 非 iOS（watchOS / macOS 单独编译时）下的 stub，仅满足类型存在。
@MainActor
final class WatchSessionController: ObservableObject {
    static let shared = WatchSessionController()
    func start(engine: ShareEngine) { /* no-op */ }
}

#endif
