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

        public struct Payload: Codable, Sendable {
            public var device: DeviceDTO?
            public var pairing: PairingDTO?
            public var offer: OfferDTO?
            public var history: HistoryDTO?
            public var deviceId: String?           // device_removed
            public var transferId: String?         // transfer_*
            public var bytesSent: UInt64?
            public var totalBytes: UInt64?
            public var speedBps: UInt64?
            public var ok: Bool?
            public var error: String?

            public init(
                device: DeviceDTO? = nil,
                pairing: PairingDTO? = nil,
                offer: OfferDTO? = nil,
                history: HistoryDTO? = nil,
                deviceId: String? = nil,
                transferId: String? = nil,
                bytesSent: UInt64? = nil,
                totalBytes: UInt64? = nil,
                speedBps: UInt64? = nil,
                ok: Bool? = nil,
                error: String? = nil
            ) {
                self.device = device
                self.pairing = pairing
                self.offer = offer
                self.history = history
                self.deviceId = deviceId
                self.transferId = transferId
                self.bytesSent = bytesSent
                self.totalBytes = totalBytes
                self.speedBps = speedBps
                self.ok = ok
                self.error = error
            }
        }
    }
}

// MARK: - 共享 schema（§3）

extension WatchBridge {
    public struct DeviceDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var displayName: String
        public var kind: String           // "mac" | "ios" | ...
        public var model: String?
        public var rttMs: Int?
        public var online: Bool
        public var trusted: Bool

        public init(id: String, displayName: String, kind: String,
                    model: String? = nil, rttMs: Int? = nil,
                    online: Bool = true, trusted: Bool = false) {
            self.id = id
            self.displayName = displayName
            self.kind = kind
            self.model = model
            self.rttMs = rttMs
            self.online = online
            self.trusted = trusted
        }
    }

    public struct PairingDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var peerName: String
        public var fingerprint: String
        public var createdAt: Int64

        public init(id: String, peerName: String, fingerprint: String, createdAt: Int64) {
            self.id = id
            self.peerName = peerName
            self.fingerprint = fingerprint
            self.createdAt = createdAt
        }
    }

    public struct OfferDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var peerId: String
        public var peerName: String
        public var kind: String       // "text" | "file" | "files"
        public var fileName: String?
        public var sizeBytes: UInt64?
        public var noteText: String?
        public var createdAt: Int64

        public init(id: String, peerId: String, peerName: String, kind: String,
                    fileName: String? = nil, sizeBytes: UInt64? = nil,
                    noteText: String? = nil, createdAt: Int64) {
            self.id = id
            self.peerId = peerId
            self.peerName = peerName
            self.kind = kind
            self.fileName = fileName
            self.sizeBytes = sizeBytes
            self.noteText = noteText
            self.createdAt = createdAt
        }
    }

    public struct HistoryDTO: Codable, Sendable, Identifiable, Equatable {
        public var id: String
        public var direction: String  // "sent" | "received"
        public var peerName: String
        public var kind: String       // "text" | "file" | "files"
        public var text: String?
        public var fileName: String?
        public var bytesTransferred: UInt64?
        public var ok: Bool
        public var completedAt: Int64

        public init(id: String, direction: String, peerName: String, kind: String,
                    text: String? = nil, fileName: String? = nil,
                    bytesTransferred: UInt64? = nil, ok: Bool, completedAt: Int64) {
            self.id = id
            self.direction = direction
            self.peerName = peerName
            self.kind = kind
            self.text = text
            self.fileName = fileName
            self.bytesTransferred = bytesTransferred
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
            fileName: offer.fileName,
            sizeBytes: offer.fileSize,
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
                fileName: nil,
                bytesTransferred: nil,
                ok: ok,
                completedAt: Int64(item.createdAt.timeIntervalSince1970)
            )
        case .file(let name, let size, _):
            var bytes: UInt64? = size
            if case .transferring(let done, _) = item.status { bytes = done }
            self.init(
                id: item.id.uuidString,
                direction: direction,
                peerName: item.peer.name,
                kind: "file",
                text: nil,
                fileName: name,
                bytesTransferred: bytes,
                ok: ok,
                completedAt: Int64(item.createdAt.timeIntervalSince1970)
            )
        }
    }
}

extension WatchBridge {
    static func kindLabel(for os: DeviceOS) -> String {
        switch os {
        case .ios:     return "ios"
        case .macos:   return "mac"
        case .android: return "android"
        case .windows: return "win"
        case .linux:   return "linux"
        }
    }
}
