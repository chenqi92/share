import Foundation

/// Companion 桥接协议 v=1 的命令 / 事件 / 共享状态 schema。
/// 对齐 `protocol/companion-bridges.md`。
/// Watch 端不连 LAN，所有类型都是从 iPhone 桥接侧透传过来的。

enum BridgeProtocol {
    static let version: Int = 1
}

// MARK: - 命令 (A → B)

enum BridgeCommandType: String, Codable {
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

struct BridgeCommand: Codable {
    let v: Int
    let id: String
    let type: BridgeCommandType
    let ts: Int64
    let payload: [String: AnyCodable]

    init(type: BridgeCommandType, payload: [String: AnyCodable] = [:]) {
        self.v = BridgeProtocol.version
        self.id = "cmd-" + UUID().uuidString.lowercased()
        self.type = type
        self.ts = Int64(Date().timeIntervalSince1970)
        self.payload = payload
    }
}

/// 命令回执 (B → A)
struct BridgeAck: Codable {
    let v: Int
    let id: String
    let ok: Bool
    let error: String?
    let result: [String: AnyCodable]?
}

// MARK: - 事件 (B → A)

enum BridgeEventType: String, Codable {
    case deviceAdded      = "device_added"
    case deviceRemoved    = "device_removed"
    case deviceUpdated    = "device_updated"
    case pairingPending   = "pairing_pending"
    case offerPending     = "offer_pending"
    case transferProgress = "transfer_progress"
    case transferDone     = "transfer_done"
    case historyAdded     = "history_added"
}

struct BridgeEvent: Codable {
    let v: Int
    let id: String
    let type: BridgeEventType
    let ts: Int64
    let payload: [String: AnyCodable]
}

// MARK: - 共享状态 schema

struct BridgeDevice: Codable, Identifiable, Hashable {
    let id: String
    var displayName: String
    var kind: String
    var model: String?
    var ip: String?
    var rttMs: Int?
    var online: Bool
    var trusted: Bool
    var busy: Bool
}

struct BridgePairing: Codable, Identifiable, Hashable {
    let id: String
    let peerName: String
    let code: String
    let fingerprint: String
    let createdAt: Int64
}

struct BridgeOffer: Codable, Identifiable, Hashable {
    let id: String
    let peerId: String
    let peerName: String
    let kind: String
    let files: [BridgeFileMeta]
    let noteText: String?
    let createdAt: Int64
}

struct BridgeFileMeta: Codable, Hashable {
    let name: String
    let sizeBytes: Int64
    let mime: String?
}

struct BridgeHistoryItem: Codable, Identifiable, Hashable {
    let id: String
    let direction: String
    let peerName: String
    let kind: String
    let text: String?
    let files: [BridgeFileMeta]?
    let bytesTransferred: Int64?
    let ok: Bool
    let completedAt: Int64
}

struct BridgeTransferProgress: Codable, Hashable {
    let id: String
    let bytesSent: Int64
    let totalBytes: Int64
    let speedBps: Int64?
    /// 派生字段（事件里没有，UI 算出来用）
    var progressPercent: Int {
        guard totalBytes > 0 else { return 0 }
        return min(100, Int(bytesSent * 100 / totalBytes))
    }
}

// MARK: - AnyCodable

/// `[String: Any]` payload 的 Codable 桥接器。
/// JSON 里的 String / Int / Double / Bool / Array / Dictionary / null 都能往返。
struct AnyCodable: Codable, Hashable {
    let value: Any?

    init(_ value: Any?) { self.value = value }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self.value = nil; return }
        if let v = try? c.decode(Bool.self)   { self.value = v; return }
        if let v = try? c.decode(Int64.self)  { self.value = v; return }
        if let v = try? c.decode(Double.self) { self.value = v; return }
        if let v = try? c.decode(String.self) { self.value = v; return }
        if let v = try? c.decode([AnyCodable].self) {
            self.value = v.map(\.value); return
        }
        if let v = try? c.decode([String: AnyCodable].self) {
            self.value = v.mapValues(\.value); return
        }
        self.value = nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case nil:
            try c.encodeNil()
        case let v as Bool:
            try c.encode(v)
        case let v as Int:
            try c.encode(Int64(v))
        case let v as Int64:
            try c.encode(v)
        case let v as Double:
            try c.encode(v)
        case let v as String:
            try c.encode(v)
        case let v as [Any?]:
            try c.encode(v.map(AnyCodable.init))
        case let v as [String: Any?]:
            try c.encode(v.mapValues(AnyCodable.init))
        default:
            try c.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // 仅用于 Codable 字典 hash 兼容；语义上 payload 不做集合去重。
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}

// MARK: - JSON 编解码

enum BridgeCodec {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()

    static let decoder = JSONDecoder()

    /// WCSession.sendMessage 收发 `[String: Any]`，所以把 Codable 对象转成 dict 再交给 WC。
    static func dict<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "BridgeCodec", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "顶层不是 JSON 对象"])
        }
        return obj
    }

    static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try decoder.decode(type, from: data)
    }

    /// 从 AnyCodable 字典反序列化（事件 payload 路径）。
    static func decode<T: Decodable>(_ type: T.Type, fromPayload map: [String: AnyCodable]) throws -> T {
        let data = try encoder.encode(map)
        return try decoder.decode(type, from: data)
    }
}
