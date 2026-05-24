import Foundation

/// 帧格式与编解码工具。规范见 [transport.md](../../../protocol/transport.md)。
///
/// ```
/// +--------+------+----------------------+
/// | u32 BE | u8   | body (length-1 bytes)|
/// | length | type |                      |
/// +--------+------+----------------------+
/// ```
public enum Frame {
    public static let maxLength = 16 * 1024 * 1024  // 16 MiB

    public enum FrameError: Error, Equatable {
        case lengthOutOfRange(UInt32)
        case incompleteHeader
        case incompleteBody
    }

    public static func encode(type: UInt8, body: Data) -> Data {
        let length = UInt32(body.count + 1)
        precondition(length <= maxLength, "frame too large")
        var out = Data(capacity: 4 + 1 + body.count)
        out.append(contentsOf: [
            UInt8((length >> 24) & 0xff),
            UInt8((length >> 16) & 0xff),
            UInt8((length >> 8) & 0xff),
            UInt8(length & 0xff),
        ])
        out.append(type)
        out.append(body)
        return out
    }

    /// 从缓冲区头部尝试解出一个 frame。返回 (type, body, 消耗字节数)。
    /// 数据不足返回 nil；长度非法抛错。
    public static func decode(_ buffer: Data) throws -> (type: UInt8, body: Data, consumed: Int)? {
        guard buffer.count >= 4 else { return nil }
        let length = buffer.withUnsafeBytes { raw -> UInt32 in
            let p = raw.bindMemory(to: UInt8.self)
            return (UInt32(p[0]) << 24)
                 | (UInt32(p[1]) << 16)
                 | (UInt32(p[2]) << 8)
                 |  UInt32(p[3])
        }
        guard length >= 1, length <= maxLength else {
            throw FrameError.lengthOutOfRange(length)
        }
        let total = 4 + Int(length)
        guard buffer.count >= total else { return nil }
        let type = buffer[buffer.startIndex + 4]
        let body = buffer.subdata(in: (buffer.startIndex + 5)..<(buffer.startIndex + total))
        return (type, body, total)
    }
}

/// 消息类型常量，见 [messages.md](../../../protocol/messages.md)。
public enum MessageType {
    public static let hello: UInt8        = 0x01
    public static let helloAck: UInt8     = 0x02
    public static let text: UInt8         = 0x10
    public static let fileOffer: UInt8    = 0x20
    public static let fileAccept: UInt8   = 0x21
    public static let fileReject: UInt8   = 0x22
    public static let fileComplete: UInt8 = 0x23
    public static let fileCancel: UInt8   = 0x25
    public static let fileChunk: UInt8    = 0x30
    public static let ping: UInt8         = 0xF0
    public static let pong: UInt8         = 0xF1
}
