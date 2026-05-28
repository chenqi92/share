import Foundation
import Combine
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "GatewayCommands")

/// 把 protocol/companion-bridges.md §1 命令路由到 ShareEngine。
///
/// - dispatch: 接收 JSON 命令字节，路由到 engine，返回 JSON 回执字节。
/// - 事件订阅：listen 一个 connection (closure)，会收到 state_snapshot 首帧 + 后续
///   device_snapshot / pairing_pending / offer_pending / history_snapshot 事件 JSON。
@MainActor
public final class GatewayCommands {
    private let engine: ShareEngine

    public init(engine: ShareEngine) {
        self.engine = engine
    }

    // MARK: - 命令分发

    /// 解析 JSON 命令并执行，返回回执 JSON 字节。
    /// 调用方可以来自任意 actor（内部已 hop 到 MainActor）。
    public func dispatch(_ requestJSON: Data) -> Data {
        guard
            let obj = try? JSONSerialization.jsonObject(with: requestJSON) as? [String: Any]
        else {
            return Self.makeReply(id: "", ok: false, error: "invalid_json")
        }
        let cmdID = (obj["id"] as? String) ?? ""
        let type = (obj["type"] as? String) ?? ""
        let payload = (obj["payload"] as? [String: Any]) ?? [:]

        switch type {
        case "list_devices":
            return Self.makeReply(id: cmdID, ok: true, result: [
                "devices": engine.devices.map(deviceWire),
            ])

        case "get_state":
            return Self.makeReply(id: cmdID, ok: true, result: stateSnapshotPayload())

        case "send_text":
            let peerId = (payload["peerId"] as? String) ?? ""
            let text = (payload["text"] as? String) ?? ""
            guard let dev = engine.devices.first(where: { $0.id == peerId }) else {
                return Self.makeReply(id: cmdID, ok: false, error: "peer_not_found")
            }
            engine.sendText(to: dev, content: text)
            return Self.makeReply(id: cmdID, ok: true)

        case "send_file_ref":
            let peerId = (payload["peerId"] as? String) ?? ""
            let fileRef = (payload["fileRef"] as? String) ?? ""
            guard let dev = engine.devices.first(where: { $0.id == peerId }) else {
                return Self.makeReply(id: cmdID, ok: false, error: "peer_not_found")
            }
            let url = URL(fileURLWithPath: fileRef)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return Self.makeReply(id: cmdID, ok: false, error: "file_ref_invalid")
            }
            engine.sendFile(to: dev, sourceURL: url)
            return Self.makeReply(id: cmdID, ok: true)

        case "accept_offer":
            let offerId = (payload["offerId"] as? String) ?? ""
            guard let uuid = UUID(uuidString: offerId) else {
                return Self.makeReply(id: cmdID, ok: false, error: "bad_offer_id")
            }
            engine.respondToFileOffer(uuid, accept: true)
            return Self.makeReply(id: cmdID, ok: true)

        case "reject_offer":
            let offerId = (payload["offerId"] as? String) ?? ""
            guard let uuid = UUID(uuidString: offerId) else {
                return Self.makeReply(id: cmdID, ok: false, error: "bad_offer_id")
            }
            engine.respondToFileOffer(uuid, accept: false)
            return Self.makeReply(id: cmdID, ok: true)

        case "accept_pairing":
            let pairId = (payload["pairingId"] as? String) ?? ""
            let trust = (payload["trust"] as? Bool) ?? false
            guard let uuid = UUID(uuidString: pairId) else {
                return Self.makeReply(id: cmdID, ok: false, error: "bad_pairing_id")
            }
            engine.respondToPairing(uuid, decision: trust ? .trust : .allowOnce)
            return Self.makeReply(id: cmdID, ok: true)

        case "reject_pairing":
            let pairId = (payload["pairingId"] as? String) ?? ""
            guard let uuid = UUID(uuidString: pairId) else {
                return Self.makeReply(id: cmdID, ok: false, error: "bad_pairing_id")
            }
            engine.respondToPairing(uuid, decision: .reject)
            return Self.makeReply(id: cmdID, ok: true)

        case "clear_history":
            engine.clearHistory()
            return Self.makeReply(id: cmdID, ok: true)

        case "cancel_transfer":
            let itemId = (payload["itemId"] as? String) ?? ""
            guard let uuid = UUID(uuidString: itemId) else {
                return Self.makeReply(id: cmdID, ok: false, error: "bad_item_id")
            }
            engine.cancelTransfer(uuid)
            return Self.makeReply(id: cmdID, ok: true)

        case "delete_history_item":
            let itemId = (payload["itemId"] as? String) ?? ""
            guard let uuid = UUID(uuidString: itemId) else {
                return Self.makeReply(id: cmdID, ok: false, error: "bad_item_id")
            }
            engine.removeHistoryItem(uuid)
            return Self.makeReply(id: cmdID, ok: true)

        default:
            return Self.makeReply(id: cmdID, ok: false, error: "unsupported_command")
        }
    }

    // MARK: - 下载查找

    /// 在 history 中找匹配的 incoming 文件，返回 (filename, fileURL)。
    /// 用于 `GET /api/v1/download/<historyId>`。
    public func fileForHistory(id: UUID) -> (name: String, url: URL)? {
        guard let item = engine.history.first(where: { $0.id == id }),
              item.direction == .incoming,
              case .file(let name, _, let url) = item.kind,
              let url else {
            return nil
        }
        return (name, url)
    }

    // MARK: - 事件订阅

    /// 给一个 WS 连接订阅 engine 状态变化。
    /// 返回的 cancellables 集合一旦释放就停止推送。
    ///
    /// 推送的事件 JSON 与 web client `engine.ts` 期望对齐：
    /// - `state_snapshot` 首帧（含 self / devices / history）
    /// - `device_snapshot`（devices 变化）
    /// - `history_snapshot`（history 变化）
    /// - `pairing_pending`（每个新增的 pairing）
    /// - `offer_pending`（每个新增的 offer）
    public func subscribe(send: @escaping (Data) -> Void) -> Set<AnyCancellable> {
        var bag = Set<AnyCancellable>()

        // 首帧：完整状态快照
        send(Self.encodeEvent(type: "state_snapshot", payload: stateSnapshotPayload()))

        // 后续 device 变化：去重避免初始重复推送
        engine.$devices
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] devices in
                guard let self else { return }
                let json = Self.encodeEvent(type: "device_snapshot", payload: devices.map(self.deviceWire))
                send(json)
            }
            .store(in: &bag)

        engine.$history
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] history in
                guard let self else { return }
                let json = Self.encodeEvent(type: "history_snapshot", payload: history.map(self.historyWire))
                send(json)
            }
            .store(in: &bag)

        engine.$pendingPairings
            .dropFirst()
            .scan(([] as [PairingRequest], [] as [PairingRequest])) { state, new in
                (state.1, new)
            }
            .sink { [weak self] previous, current in
                guard let self else { return }
                let newOnes = current.filter { p in !previous.contains(where: { $0.id == p.id }) }
                for p in newOnes {
                    send(Self.encodeEvent(type: "pairing_pending", payload: self.pairingWire(p)))
                }
            }
            .store(in: &bag)

        engine.$pendingFileOffers
            .dropFirst()
            .scan(([] as [PendingFileOffer], [] as [PendingFileOffer])) { state, new in
                (state.1, new)
            }
            .sink { [weak self] previous, current in
                guard let self else { return }
                let newOnes = current.filter { o in !previous.contains(where: { $0.id == o.id }) }
                for o in newOnes {
                    send(Self.encodeEvent(type: "offer_pending", payload: self.offerWire(o)))
                }
            }
            .store(in: &bag)

        // 进行中传输的速率推送：每个 metrics 字典变化，挑出当前 transferring 的
        // history 条目，包成 WireTransferProgress 推给 web。
        engine.$transferMetrics
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] metrics in
                guard let self else { return }
                for (hid, m) in metrics {
                    guard let item = self.engine.history.first(where: { $0.id == hid }),
                          case let .transferring(done, total) = item.status,
                          case let .file(name, _, _) = item.kind
                    else { continue }
                    var payload: [String: Any] = [
                        "id": hid.uuidString,
                        "peerName": item.peer.name,
                        "fileName": name,
                        "bytesSent": Int(done),
                        "totalBytes": Int(total),
                        "speedBps": Int(m.bytesPerSec.rounded()),
                    ]
                    if let etaSec = m.etaSeconds {
                        payload["etaSeconds"] = etaSec
                    }
                    send(Self.encodeEvent(type: "transfer_progress", payload: payload))
                }
            }
            .store(in: &bag)

        return bag
    }

    // MARK: - schema 编码（与 web/src/lib/engine.ts `Wire*` 对齐）

    private func stateSnapshotPayload() -> [String: Any] {
        return [
            "self": [
                "id": engine.identity.id,
                "displayName": engine.displayName,
                "kind": Self.kindString(for: DeviceOS.current),
                "fingerprint": engine.identity.fingerprint,
            ] as [String: Any],
            "devices": engine.devices.map(deviceWire),
            "history": engine.history.map(historyWire),
            "pendingPairings": engine.pendingPairings.map(pairingWire),
            "pendingOffers": engine.pendingFileOffers.map(offerWire),
        ]
    }

    private func deviceWire(_ d: Device) -> [String: Any] {
        var obj: [String: Any] = [
            "id": d.id,
            "displayName": d.name,
            "kind": Self.kindString(for: d.os),
            "fingerprint": d.fingerprint,
            "online": true,
            "trusted": engine.trusted.contains(where: { $0.fingerprint == d.fingerprint }),
        ]
        if let m = d.model { obj["model"] = m }
        return obj
    }

    private func historyWire(_ h: HistoryItem) -> [String: Any] {
        var obj: [String: Any] = [
            "id": h.id.uuidString,
            "direction": h.direction == .outgoing ? "sent" : "received",
            "peerName": h.peer.name,
            "ok": {
                if case .completed = h.status { return true } else { return false }
            }(),
            "completedAt": Int(h.createdAt.timeIntervalSince1970),
        ]
        switch h.kind {
        case .text(let t):
            obj["kind"] = "text"
            obj["text"] = t
        case .file(let name, let size, _):
            obj["kind"] = "file"
            obj["files"] = [["name": name, "sizeBytes": Int(size)]]
            obj["bytesTransferred"] = Int(size)
        }
        return obj
    }

    private func pairingWire(_ p: PairingRequest) -> [String: Any] {
        return [
            "id": p.id.uuidString,
            "peerName": p.peer.name,
            "fingerprint": p.peer.humanFingerprint,
            "createdAt": Int(p.receivedAt.timeIntervalSince1970),
        ]
    }

    private func offerWire(_ o: PendingFileOffer) -> [String: Any] {
        return [
            "id": o.id.uuidString,
            "peerId": o.peer.id,
            "peerName": o.peer.name,
            "kind": "file",
            "files": [["name": o.fileName, "sizeBytes": Int(o.fileSize)]],
            "createdAt": Int(o.receivedAt.timeIntervalSince1970),
        ]
    }

    private static func kindString(for os: DeviceOS) -> String {
        switch os {
        case .macos: return "mac"
        case .ios: return "ios"
        case .windows: return "win"
        case .android: return "android"
        case .linux: return "linux"
        }
    }

    // MARK: - reply / event 包装

    public nonisolated static func makeReply(id: String, ok: Bool, error: String? = nil, result: Any? = nil) -> Data {
        var obj: [String: Any] = [
            "v": 1,
            "id": id,
            "ok": ok,
        ]
        if let error { obj["error"] = error } else { obj["error"] = NSNull() }
        if let result { obj["result"] = result } else { obj["result"] = NSNull() }
        return (try? JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed])) ?? Data()
    }

    public nonisolated static func encodeEvent(type: String, payload: Any) -> Data {
        let obj: [String: Any] = [
            "v": 1,
            "id": "evt-\(UUID().uuidString.lowercased().prefix(12))",
            "type": type,
            "ts": Int(Date().timeIntervalSince1970),
            "payload": payload,
        ]
        return (try? JSONSerialization.data(withJSONObject: obj, options: [.fragmentsAllowed])) ?? Data()
    }
}
