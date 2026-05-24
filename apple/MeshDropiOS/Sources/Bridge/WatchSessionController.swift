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
        // device 列表变化：发送 device_added / device_removed
        var lastDevices: [String: WatchBridge.DeviceDTO] = [:]
        engine.$devices
            .sink { [weak self] devices in
                guard let self else { return }
                let next = Dictionary(
                    uniqueKeysWithValues: devices.map { ($0.id, WatchBridge.DeviceDTO(from: $0)) }
                )
                // added / updated
                for (id, dto) in next {
                    if let prev = lastDevices[id] {
                        if prev != dto {
                            self.push(event: .init(type: .deviceUpdated,
                                                   payload: .init(device: dto)))
                        }
                    } else {
                        self.push(event: .init(type: .deviceAdded,
                                               payload: .init(device: dto)))
                    }
                }
                // removed
                for id in lastDevices.keys where next[id] == nil {
                    self.push(event: .init(type: .deviceRemoved,
                                           payload: .init(deviceId: id)))
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
                    self.push(event: .init(type: .pairingPending,
                                           payload: .init(pairing: .init(from: req))))
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
                    self.push(event: .init(type: .offerPending,
                                           payload: .init(offer: .init(from: offer))))
                }
            }
            .store(in: &subs)

        // history: 新增推 history_added，transferring 项节流推 transfer_progress / transfer_done
        var seenHistory: Set<UUID> = []
        var lastProgressAt: [UUID: Date] = [:]
        engine.$history
            .sink { [weak self] items in
                guard let self else { return }
                for item in items {
                    if !seenHistory.contains(item.id) {
                        seenHistory.insert(item.id)
                        self.push(event: .init(type: .historyAdded,
                                               payload: .init(history: .init(from: item))))
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
                        self.push(event: .init(type: .transferProgress,
                                               payload: .init(transferId: item.id.uuidString,
                                                              bytesSent: done,
                                                              totalBytes: total)))
                    case .completed:
                        self.push(event: .init(type: .transferDone,
                                               payload: .init(transferId: item.id.uuidString,
                                                              ok: true)))
                    case .failed(let msg):
                        self.push(event: .init(type: .transferDone,
                                               payload: .init(transferId: item.id.uuidString,
                                                              ok: false, error: msg)))
                    default:
                        break
                    }
                }
            }
            .store(in: &subs)
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

    // MARK: - 推事件 / 回执（统一封装错误日志）

    private func push(event: WatchBridge.Event) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated, session.isReachable else { return }
        do {
            let dict = try WatchBridge.encode(event)
            session.sendMessage(dict, replyHandler: nil) { err in
                log.debug("push event \(event.type.rawValue) 失败：\(err.localizedDescription)")
            }
        } catch {
            log.error("encode event 失败：\(error.localizedDescription)")
        }
    }

    // MARK: - 命令路由（watch → phone）

    fileprivate func handle(command: WatchBridge.Command) async -> WatchBridge.Response {
        guard let engine else {
            return WatchBridge.Response(id: command.id, ok: false, error: "engine_not_ready")
        }
        switch command.type {
        case .listDevices:
            return WatchBridge.Response(
                id: command.id, ok: true,
                result: .init(devices: engine.devices.map { .init(from: $0) })
            )

        case .getState:
            return WatchBridge.Response(
                id: command.id, ok: true,
                result: .init(
                    devices: engine.devices.map { .init(from: $0) },
                    history: engine.history.prefix(50).map { .init(from: $0) },
                    pendingPairings: engine.pendingPairings.map { .init(from: $0) },
                    pendingOffers: engine.pendingFileOffers.map { .init(from: $0) }
                )
            )

        case .sendText:
            guard let pid = command.payload?.peerId,
                  let text = command.payload?.text,
                  let peer = engine.devices.first(where: { $0.id == pid }) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "peer_or_text_missing")
            }
            engine.sendText(to: peer, content: text)
            return WatchBridge.Response(id: command.id, ok: true)

        case .sendFileRef:
            guard let pid = command.payload?.peerId,
                  let ref = command.payload?.fileRef,
                  let peer = engine.devices.first(where: { $0.id == pid }) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "peer_or_fileref_missing")
            }
            // watch 在 transferFile 时把文件写到 phone container 的 ref URL，这里按约定从
            // `Library/Caches/com.welape.meshdrop.watchbridge/<ref>` 读取。
            let url = Self.fileRefURL(for: ref)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "fileref_not_found")
            }
            engine.sendFile(to: peer, sourceURL: url)
            return WatchBridge.Response(id: command.id, ok: true)

        case .acceptOffer:
            guard let oid = command.payload?.offerId, let uuid = UUID(uuidString: oid) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "offerId_missing")
            }
            engine.respondToFileOffer(uuid, accept: true)
            return WatchBridge.Response(id: command.id, ok: true)

        case .rejectOffer:
            guard let oid = command.payload?.offerId, let uuid = UUID(uuidString: oid) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "offerId_missing")
            }
            engine.respondToFileOffer(uuid, accept: false)
            return WatchBridge.Response(id: command.id, ok: true)

        case .acceptPairing:
            guard let pid = command.payload?.pairingId, let uuid = UUID(uuidString: pid) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "pairingId_missing")
            }
            let trust = command.payload?.trust ?? false
            engine.respondToPairing(uuid, decision: trust ? .trust : .allowOnce)
            return WatchBridge.Response(id: command.id, ok: true)

        case .rejectPairing:
            guard let pid = command.payload?.pairingId, let uuid = UUID(uuidString: pid) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "pairingId_missing")
            }
            engine.respondToPairing(uuid, decision: .reject)
            return WatchBridge.Response(id: command.id, ok: true)

        case .clearHistory:
            engine.clearHistory()
            return WatchBridge.Response(id: command.id, ok: true)

        case .deleteHistoryItem:
            guard let iid = command.payload?.itemId, let uuid = UUID(uuidString: iid) else {
                return WatchBridge.Response(id: command.id, ok: false, error: "itemId_missing")
            }
            engine.removeHistoryItem(uuid)
            return WatchBridge.Response(id: command.id, ok: true)
        }
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
                let resp = await Self.shared.handle(command: cmd)
                let dict = (try? WatchBridge.encode(resp)) ?? [
                    "v": WatchBridge.protocolVersion, "id": cmd.id, "ok": false, "error": "encode_failed"
                ]
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
    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let fm = FileManager.default
        let ref = file.metadata?["ref"] as? String ?? UUID().uuidString
        let dst = WatchSessionController.fileRefURL(for: ref)
        do {
            if fm.fileExists(atPath: dst.path) {
                try fm.removeItem(at: dst)
            }
            try fm.moveItem(at: file.fileURL, to: dst)
            log.info("watch 文件落盘 ref=\(ref)")
        } catch {
            log.error("watch 文件移动失败：\(error.localizedDescription)")
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
