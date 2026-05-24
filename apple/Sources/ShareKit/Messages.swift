import Foundation

/// JSON 编码的控制消息。字段定义见 [messages.md](../../../protocol/messages.md)。

public struct HelloMessage: Codable, Sendable {
    public var id: String
    public var name: String
    public var os: DeviceOS
    public var model: String?
    public var fp: String
    public var protocol_versions: [UInt8]

    public init(id: String, name: String, os: DeviceOS, model: String?, fp: String, protocol_versions: [UInt8]) {
        self.id = id
        self.name = name
        self.os = os
        self.model = model
        self.fp = fp
        self.protocol_versions = protocol_versions
    }
}

public struct HelloAckMessage: Codable, Sendable {
    public var id: String
    public var name: String
    public var os: DeviceOS
    public var model: String?
    public var fp: String
    public var protocol_versions: [UInt8]
    public var selected_version: UInt8
}

public struct TextMessage: Codable, Sendable {
    public var id: String          // UUID v4
    public var content: String
    public var ts: Int64           // Unix 秒
}

public struct FileMeta: Codable, Sendable {
    public var index: Int
    public var name: String
    public var size: UInt64
    public var sha256: String
}

public struct FileOfferMessage: Codable, Sendable {
    public var transfer_id: String
    public var files: [FileMeta]
}

public struct FileAcceptMessage: Codable, Sendable {
    public var transfer_id: String
    public var index: Int
    public var resume_offset: UInt64
}

public struct FileRejectMessage: Codable, Sendable {
    public var transfer_id: String
    public var index: Int
    public var reason: String
}

public struct FileCompleteMessage: Codable, Sendable {
    public var transfer_id: String
    public var index: Int
}

public struct FileCancelMessage: Codable, Sendable {
    public var transfer_id: String
    public var index: Int?
    public var reason: String
}

/// 二进制 FILE_CHUNK 的头部解析（不含 data）。
public struct FileChunkHeader: Sendable {
    public static let size = 16 + 4 + 8

    public let transferID: UUID
    public let index: UInt32
    public let offset: UInt64

    public init(transferID: UUID, index: UInt32, offset: UInt64) {
        self.transferID = transferID
        self.index = index
        self.offset = offset
    }

    public static func encode(_ header: FileChunkHeader, data: Data) -> Data {
        var out = Data(capacity: size + data.count)
        out.append(contentsOf: withUnsafeBytes(of: header.transferID.uuid) { Array($0) })

        var idx = header.index.bigEndian
        withUnsafeBytes(of: &idx) { out.append(contentsOf: $0) }

        var off = header.offset.bigEndian
        withUnsafeBytes(of: &off) { out.append(contentsOf: $0) }

        out.append(data)
        return out
    }

    public static func decode(_ body: Data) -> (header: FileChunkHeader, data: Data)? {
        guard body.count >= size else { return nil }
        let start = body.startIndex
        // 使用 loadUnaligned：Data 是 byte 对齐的，offset 16/20 处的 u32/u64 不
        // 满足自然对齐，普通 load 在 ARM 上会 trap。
        let uuidBytes: uuid_t = body.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: 0, as: uuid_t.self)
        }
        let index = body.withUnsafeBytes { raw -> UInt32 in
            raw.loadUnaligned(fromByteOffset: 16, as: UInt32.self).bigEndian
        }
        let offset = body.withUnsafeBytes { raw -> UInt64 in
            raw.loadUnaligned(fromByteOffset: 20, as: UInt64.self).bigEndian
        }
        let data = body.subdata(in: (start + size)..<body.endIndex)
        return (FileChunkHeader(transferID: UUID(uuid: uuidBytes), index: index, offset: offset), data)
    }
}

public enum MessageCodec {
    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
    private static let decoder = JSONDecoder()

    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try encoder.encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }
}
