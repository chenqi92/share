import Foundation
import CryptoKit

/// RFC 6455 WebSocket framing —— server 端最小子集。
///
/// 用于 [WebGateway] /api/v1/control 升级后的双向消息。手写是因为
/// `NWConnection` 内置的 WS 升级只在 client 端可用；server 侧需要自己处理
/// 101 Switching Protocols 与 frame 编解码。
///
/// 支持：
/// - text frame (opcode 1) — 发送 / 接收
/// - close frame (opcode 8)
/// - ping (opcode 9) → 自动 pong (opcode 10)
/// - 客户端→服务端必须 mask；服务端→客户端必须不 mask
/// - 负载长度 1 / 2 / 8 字节变长编码
///
/// 不支持：fragmented frames（继续 frame opcode 0），binary frame 解码
/// （send_file_ref 走 multipart upload，不走 WS binary）。
public enum WebSocketFrame {

    public enum Opcode: UInt8 {
        case continuation = 0
        case text = 1
        case binary = 2
        case close = 8
        case ping = 9
        case pong = 10
    }

    public struct Decoded {
        public let opcode: Opcode
        public let payload: Data
        public let isFinal: Bool
    }

    public enum DecodeResult {
        /// 完整 frame，含使用掉的字节数。
        case frame(Decoded, consumed: Int)
        /// buffer 还不够，等更多数据。
        case needsMore
        /// 协议错误，应关闭连接。
        case error(String)
    }

    // MARK: - 握手 Sec-WebSocket-Accept

    public static let magicGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

    /// 计算 RFC 6455 §4.2.2 的 `Sec-WebSocket-Accept` 值。
    public static func computeAccept(key: String) -> String {
        let combined = (key + magicGUID).data(using: .utf8) ?? Data()
        let hash = Insecure.SHA1.hash(data: combined)
        return Data(hash).base64EncodedString()
    }

    // MARK: - 编码（server → client，不 mask）

    public static func encode(opcode: Opcode, payload: Data, isFinal: Bool = true) -> Data {
        var out = Data()
        let finBit: UInt8 = isFinal ? 0x80 : 0x00
        out.append(finBit | (opcode.rawValue & 0x0F))

        let len = payload.count
        if len < 126 {
            out.append(UInt8(len))
        } else if len < 65536 {
            out.append(126)
            var lenBE = UInt16(len).bigEndian
            withUnsafeBytes(of: &lenBE) { out.append(contentsOf: $0) }
        } else {
            out.append(127)
            var lenBE = UInt64(len).bigEndian
            withUnsafeBytes(of: &lenBE) { out.append(contentsOf: $0) }
        }
        out.append(payload)
        return out
    }

    public static func text(_ s: String) -> Data {
        encode(opcode: .text, payload: s.data(using: .utf8) ?? Data())
    }

    public static func text(_ data: Data) -> Data {
        encode(opcode: .text, payload: data)
    }

    public static func pong(payload: Data) -> Data {
        encode(opcode: .pong, payload: payload)
    }

    public static func close(code: UInt16 = 1000, reason: String = "") -> Data {
        var p = Data()
        var codeBE = code.bigEndian
        withUnsafeBytes(of: &codeBE) { p.append(contentsOf: $0) }
        if !reason.isEmpty, let r = reason.data(using: .utf8) { p.append(r) }
        return encode(opcode: .close, payload: p)
    }

    // MARK: - 解码（client → server，必须 mask）

    public static func decode(buffer: Data) -> DecodeResult {
        guard buffer.count >= 2 else { return .needsMore }
        let bytes = [UInt8](buffer)

        let b0 = bytes[0]
        let b1 = bytes[1]
        let isFinal = (b0 & 0x80) != 0
        let opcodeRaw = b0 & 0x0F
        guard let opcode = Opcode(rawValue: opcodeRaw) else {
            return .error("unknown opcode \(opcodeRaw)")
        }
        let masked = (b1 & 0x80) != 0
        let len7 = Int(b1 & 0x7F)

        var offset = 2
        var payloadLen: Int
        if len7 < 126 {
            payloadLen = len7
        } else if len7 == 126 {
            guard bytes.count >= offset + 2 else { return .needsMore }
            let hi = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
            payloadLen = Int(hi)
            offset += 2
        } else {
            guard bytes.count >= offset + 8 else { return .needsMore }
            var v: UInt64 = 0
            for i in 0..<8 {
                v = (v << 8) | UInt64(bytes[offset + i])
            }
            if v > UInt64(Int.max) { return .error("payload too large") }
            payloadLen = Int(v)
            offset += 8
        }

        // 控制 frame 必须 < 126 字节且 isFinal
        if opcode == .close || opcode == .ping || opcode == .pong {
            if payloadLen >= 126 { return .error("control frame too large") }
            if !isFinal { return .error("control frame fragmented") }
        }

        // 客户端→服务端必须 mask
        var maskKey: [UInt8] = []
        if masked {
            guard bytes.count >= offset + 4 else { return .needsMore }
            maskKey = Array(bytes[offset..<(offset + 4)])
            offset += 4
        } else {
            return .error("client frame must be masked")
        }

        guard bytes.count >= offset + payloadLen else { return .needsMore }
        var payload = [UInt8](repeating: 0, count: payloadLen)
        for i in 0..<payloadLen {
            payload[i] = bytes[offset + i] ^ maskKey[i % 4]
        }
        let consumed = offset + payloadLen
        return .frame(Decoded(opcode: opcode, payload: Data(payload), isFinal: isFinal), consumed: consumed)
    }
}
