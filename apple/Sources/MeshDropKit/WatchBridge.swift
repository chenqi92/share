import Foundation

/// Watch Companion Bridge 协议封装（`protocol/companion-bridges.md` v0.1）。
///
/// 这一份是 **跨进程 / 跨设备的 wire format**：iPhone 端的 `WatchSessionController`
/// 和 watchOS 端的 client 都会用到。所以放在 MeshDropKit 里（同时给 iOS / macOS / watchOS
/// 编译），保持单一定义。
///
/// 协议骨架：
/// - §1 命令集：watch → phone，单条 JSON dictionary
/// - §2 事件集：phone → watch，单条 JSON dictionary
/// - §3 共享 schema：Device / Pairing / Offer / HistoryItem（用一致字段名）
public enum WatchBridge {
    /// 协议版本。与 `protocol/companion-bridges.md §6` 一致。
    public static let protocolVersion: Int = 1
}

// MARK: - 命令（watch → phone）

extension WatchBridge {
    /// `type` 字段的取值。
    public enum CommandType: String, Codable, Sendable {
        case listDevices       = "list_devices"
        case sendText          = "send_text"
        case sendFileRef       = "send_file_ref"
        case acceptOffer       = "accept_offer"
        case rejectOffer       = "reject_offer"
        case acceptPairing     = "accept_pairing"
        case rejectPairing     = "reject_pairing"
        case clearHistory      = "clear_history"
        case deleteHistoryItem = "delete_history_item"
        case getState          = "get_state"
    }

    /// 命令信封。
    public struct Command: Codable, Sendable {
        public var v: Int
        public var id: String
        public var type: CommandType
        public var ts: Int64
        public var payload: Payload?

        public init(id: String = UUID().uuidString,
                    type: CommandType,
                    payload: Payload? = nil) {
            self.v = WatchBridge.protocolVersion
            self.id = id
            self.type = type
            self.ts = Int64(Date().timeIntervalSince1970)
            self.payload = payload
        }

        /// 各命令的 payload schema 合并体。无关字段在某些 type 下保持 nil。
        public struct Payload: Codable, Sendable {
            public var peerId: String?
            public var text: String?
            public var fileRef: String?          // watch 端 transferFile 后的 uuid
            public var name: String?
            public var sizeBytes: UInt64?
            public var mime: String?
            public var offerId: String?
            public var pairingId: String?
            public var trust: Bool?
            public var scope: String?
            public var itemId: String?

            public init(
                peerId: String? = nil,
                text: String? = nil,
                fileRef: String? = nil,
                name: String? = nil,
                sizeBytes: UInt64? = nil,
                mime: String? = nil,
                offerId: String? = nil,
                pairingId: String? = nil,
                trust: Bool? = nil,
                scope: String? = nil,
                itemId: String? = nil
            ) {
                self.peerId = peerId
                self.text = text
                self.fileRef = fileRef
                self.name = name
                self.sizeBytes = sizeBytes
                self.mime = mime
                self.offerId = offerId
                self.pairingId = pairingId
                self.trust = trust
                self.scope = scope
                self.itemId = itemId
            }
        }
    }
}

// MARK: - 回执（phone → watch，与 Command.id 同步）

extension WatchBridge {
    public struct Response: Codable, Sendable {
        public var v: Int
        public var id: String
        public var ok: Bool
        public var error: String?
        public var result: Result?

        public init(id: String, ok: Bool, error: String? = nil, result: Result? = nil) {
            self.v = WatchBridge.protocolVersion
            self.id = id
            self.ok = ok
            self.error = error
            self.result = result
        }

        /// `list_devices` / `get_state` 返回的状态快照。
        public struct Result: Codable, Sendable {
            public var devices: [DeviceDTO]?
            public var history: [HistoryDTO]?
            public var pendingPairings: [PairingDTO]?
            public var pendingOffers: [OfferDTO]?

            public init(
                devices: [DeviceDTO]? = nil,
                history: [HistoryDTO]? = nil,
                pendingPairings: [PairingDTO]? = nil,
                pendingOffers: [OfferDTO]? = nil
            ) {
                self.devices = devices
                self.history = history
                self.pendingPairings = pendingPairings
                self.pendingOffers = pendingOffers
            }
        }
    }
}

// MARK: - 事件（phone → watch，主动推）

extension WatchBridge {
    public enum EventType: String, Codable, Sendable {
        case deviceAdded      = "device_added"
        case deviceRemoved    = "device_removed"
        case deviceUpdated    = "device_updated"
        case pairingPending   = "pairing_pending"
        case offerPending     = "offer_pending"
        case transferProgress = "transfer_progress"
        case transferDone     = "transfer_done"
        case historyAdded     = "history_added"
        /// phone 收到一条**入站文本** → 内联推给 watch（无需走文件通道）。
        case inboxText        = "inbox_text"
        /// phone 收到一条**入站文件**并落盘完成 → 先 transferFile 把文件送到 watch，
        /// 再推这条事件告诉 watch「ref=xxx 这个已传完的文件属于这条收件项」。
        case inboxFileReady   = "inbox_file_ready"
    }

    public struct Event: Codable, Sendable {
        public var v: Int
        public var id: String
        public var type: EventType
        public var ts: Int64
        public var payload: Payload

        public init(type: EventType, payload: Payload) {
            self.v = WatchBridge.protocolVersion
            self.id = UUID().uuidString
            self.type = type
            self.ts = Int64(Date().timeIntervalSince1970)
            self.payload = payload
        }

        /// ⚠ 事件 payload **一律 FLAT**（companion-bridges.md §2.1）：`payload` 本身就是对应
        /// DTO / 字段集，**不再嵌** `device` / `offer` / `pairing` / `history` / `inbox` 子键；
        /// id 字段统一叫 `id`（`device_removed` / `transfer_progress` / `transfer_done` 都用 `id`）。
        ///
        /// 这里仍保留 `init(device:)` / `init(deviceId:)` / `init(transferId:)` 等便捷构造器，
        /// 让 phone 侧 producer 不必改调用点；FLAT 由自定义 `encode(to:)` / `init(from:)` 完成。
        public struct Payload: Sendable {
            public var device: DeviceDTO?
            public var pairing: PairingDTO?
            public var offer: OfferDTO?
            public var history: HistoryDTO?
            /// device_removed / transfer_* 的 id（wire 上叫 `id`，不是 deviceId/transferId）。
            public var id: String?
            public var bytesSent: UInt64?
            public var totalBytes: UInt64?
            public var speedBps: UInt64?
            public var ok: Bool?
            public var error: String?
            /// inbox_text / inbox_file_ready 用：收件项内容。
            public var inbox: InboxItemDTO?

            public init(
                device: DeviceDTO? = nil,
                pairing: PairingDTO? = nil,
                offer: OfferDTO? = nil,
                history: HistoryDTO? = nil,
                id: String? = nil,
                deviceId: String? = nil,
                transferId: String? = nil,
                bytesSent: UInt64? = nil,
                totalBytes: UInt64? = nil,
                speedBps: UInt64? = nil,
                ok: Bool? = nil,
                error: String? = nil,
                inbox: InboxItemDTO? = nil
            ) {
                self.device = device
                self.pairing = pairing
                self.offer = offer
                self.history = history
                // deviceId / transferId 是历史调用点用的别名；统一收敛到 `id`。
                self.id = id ?? deviceId ?? transferId
                self.bytesSent = bytesSent
                self.totalBytes = totalBytes
                self.speedBps = speedBps
                self.ok = ok
                self.error = error
                self.inbox = inbox
            }
        }
    }
}

// MARK: - 事件 payload 的 FLAT 编解码

extension WatchBridge.Event.Payload: Codable {
    /// 标量字段（非 DTO 内联场景）的 key。device_removed / transfer_* 用 `id`。
    private enum ScalarKey: String, CodingKey {
        case id, bytesSent, totalBytes, speedBps, ok, error
    }

    /// FLAT 编码：把内联 DTO 的字段直接平铺到 payload 顶层（不再包 device/offer/... 子键），
    /// 标量字段（id/bytesSent/...）按需补上。同一 payload 至多内联一个 DTO。
    public func encode(to encoder: Encoder) throws {
        if let device { try device.encode(to: encoder); return }
        if let offer { try offer.encode(to: encoder); return }
        if let pairing { try pairing.encode(to: encoder); return }
        if let history { try history.encode(to: encoder); return }
        if let inbox { try inbox.encode(to: encoder); return }

        var c = encoder.container(keyedBy: ScalarKey.self)
        try c.encodeIfPresent(id, forKey: .id)
        try c.encodeIfPresent(bytesSent, forKey: .bytesSent)
        try c.encodeIfPresent(totalBytes, forKey: .totalBytes)
        try c.encodeIfPresent(speedBps, forKey: .speedBps)
        try c.encodeIfPresent(ok, forKey: .ok)
        try c.encodeIfPresent(error, forKey: .error)
    }

    /// FLAT 解码：仅取标量字段（DTO 内联解码由消费侧按 EventType 自行决定，phone 端不消费事件）。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ScalarKey.self)
        self.init(
            id: try c.decodeIfPresent(String.self, forKey: .id),
            bytesSent: try c.decodeIfPresent(UInt64.self, forKey: .bytesSent),
            totalBytes: try c.decodeIfPresent(UInt64.self, forKey: .totalBytes),
            speedBps: try c.decodeIfPresent(UInt64.self, forKey: .speedBps),
            ok: try c.decodeIfPresent(Bool.self, forKey: .ok),
            error: try c.decodeIfPresent(String.self, forKey: .error)
        )
    }
}

// MARK: - 共享 schema（§3）

extension WatchBridge {
    /// Offer / HistoryItem 的 `files[]` 元素（companion-bridges.md §3.1 FileMeta）。
    public struct FileMetaDTO: Codable, Sendable, Equatable {
        public var name: String
        public var sizeBytes: UInt64
        public var mime: String

        public init(name: String, sizeBytes: UInt64, mime: String = "application/octet-stream") {
            self.name = name
            self.sizeBytes = sizeBytes
            self.mime = mime
        }
    }

    public struct DeviceDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var displayName: String
        public var kind: String           // "mac" | "ios" | ...
        public var model: String
        public var ip: String
        public var rttMs: Int
        public var online: Bool
        public var trusted: Bool
        public var busy: Bool

        public init(id: String, displayName: String, kind: String,
                    model: String? = nil, ip: String? = nil, rttMs: Int? = nil,
                    online: Bool = true, trusted: Bool = false, busy: Bool = false) {
            self.id = id
            self.displayName = displayName
            self.kind = kind
            // 规范默认：model/ip 空串、rttMs=0（companion-bridges.md §3.1）。
            self.model = model ?? ""
            self.ip = ip ?? ""
            self.rttMs = rttMs ?? 0
            self.online = online
            self.trusted = trusted
            self.busy = busy
        }
    }

    public struct PairingDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var peerName: String
        public var code: String
        public var fingerprint: String
        public var createdAt: Int64

        public init(id: String, peerName: String, code: String? = nil,
                    fingerprint: String, createdAt: Int64) {
            self.id = id
            self.peerName = peerName
            self.code = code ?? ""
            self.fingerprint = fingerprint
            self.createdAt = createdAt
        }
    }

    public struct OfferDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var peerId: String
        public var peerName: String
        public var kind: String       // "text" | "file" | "files"
        public var files: [FileMetaDTO]
        public var noteText: String?
        public var createdAt: Int64

        public init(id: String, peerId: String, peerName: String, kind: String,
                    files: [FileMetaDTO] = [], noteText: String? = nil, createdAt: Int64) {
            self.id = id
            self.peerId = peerId
            self.peerName = peerName
            self.kind = kind
            self.files = files
            self.noteText = noteText
            self.createdAt = createdAt
        }
    }

    /// 入站收件项（phone → watch）。文本内联在 `text`；文件已经过 `transferFile` 送到 watch，
    /// `fileRef` 给出落盘文件名，watch 端按约定路径取。
    public struct InboxItemDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String          // = phone 端 historyID.uuidString
        public var peerName: String
        public var kind: String        // "text" | "file"
        public var text: String?
        public var fileName: String?
        public var sizeBytes: UInt64?
        public var fileRef: String?    // transferFile 落盘的引用名（kind==file）
        public var receivedAt: Int64

        public init(id: String, peerName: String, kind: String,
                    text: String? = nil, fileName: String? = nil,
                    sizeBytes: UInt64? = nil, fileRef: String? = nil,
                    receivedAt: Int64) {
            self.id = id
            self.peerName = peerName
            self.kind = kind
            self.text = text
            self.fileName = fileName
            self.sizeBytes = sizeBytes
            self.fileRef = fileRef
            self.receivedAt = receivedAt
        }
    }

    public struct HistoryDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var direction: String  // "sent" | "received"
        public var peerName: String
        public var kind: String       // "text" | "file" | "files"
        public var text: String?
        public var files: [FileMetaDTO]
        public var bytesTransferred: UInt64
        public var ok: Bool
        public var completedAt: Int64

        public init(id: String, direction: String, peerName: String, kind: String,
                    text: String? = nil, files: [FileMetaDTO] = [],
                    bytesTransferred: UInt64? = nil, ok: Bool, completedAt: Int64) {
            self.id = id
            self.direction = direction
            self.peerName = peerName
            self.kind = kind
            self.text = text
            self.files = files
            self.bytesTransferred = bytesTransferred ?? 0
            self.ok = ok
            self.completedAt = completedAt
        }
    }
}

// MARK: - JSON 编 / 解码（WCSession.sendMessage 的 payload）

extension WatchBridge {
    /// `WCSession.sendMessage` 要求 dictionary，命令 / 事件统一序列化为 `[String: Any]`。
    /// 用 JSONEncoder + JSONSerialization 中转，避免手写每字段映射。
    public static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EncodingError.invalidValue(value, .init(codingPath: [], debugDescription: "不是 dict"))
        }
        return dict
    }

    public static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(type, from: data)
    }
}

// MARK: - 内部数据 ⇄ DTO 映射

extension WatchBridge.DeviceDTO {
    public init(from device: Device, trusted: Bool = false) {
        self.init(
            id: device.id,
            displayName: device.name,
            kind: WatchBridge.kindLabel(for: device.os),
            model: device.model,
            rttMs: nil,
            online: true,
            trusted: trusted
        )
    }
}

extension WatchBridge.PairingDTO {
    public init(from req: PairingRequest) {
        self.init(
            id: req.id.uuidString,
            peerName: req.peer.name,
            fingerprint: req.peer.humanFingerprint,
            createdAt: Int64(req.receivedAt.timeIntervalSince1970)
        )
    }
}

extension WatchBridge.OfferDTO {
    public init(from offer: PendingFileOffer) {
        self.init(
            id: offer.id.uuidString,
            peerId: offer.peer.id,
            peerName: offer.peer.name,
            kind: "file",
            files: [WatchBridge.FileMetaDTO(
                name: offer.fileName,
                sizeBytes: offer.fileSize,
                mime: offer.mime ?? "application/octet-stream"
            )],
            noteText: nil,
            createdAt: Int64(offer.receivedAt.timeIntervalSince1970)
        )
    }
}

extension WatchBridge.HistoryDTO {
    public init(from item: HistoryItem) {
        let direction = (item.direction == .outgoing) ? "sent" : "received"
        let ok: Bool
        switch item.status {
        case .completed: ok = true
        default: ok = false
        }
        switch item.kind {
        case .text(let content):
            self.init(
                id: item.id.uuidString,
                direction: direction,
                peerName: item.peer.name,
                kind: "text",
                text: content,
                files: [],
                bytesTransferred: 0,
                ok: ok,
                completedAt: Int64(item.createdAt.timeIntervalSince1970)
            )
        case .file(let name, let size, _):
            var bytes: UInt64 = size
            if case .transferring(let done, _) = item.status { bytes = done }
            self.init(
                id: item.id.uuidString,
                direction: direction,
                peerName: item.peer.name,
                kind: "file",
                text: nil,
                files: [WatchBridge.FileMetaDTO(name: name, sizeBytes: size)],
                bytesTransferred: bytes,
                ok: ok,
                completedAt: Int64(item.createdAt.timeIntervalSince1970)
            )
        }
    }
}

extension WatchBridge {
    public static func kindLabel(for os: DeviceOS) -> String {
        switch os {
        case .ios:     return "ios"
        case .macos:   return "mac"
        case .android: return "android"
        case .windows: return "win"
        case .linux:   return "linux"
        }
    }
}
