import Foundation
import Network

/// mDNS TXT 记录的编解码。字段见 [discovery.md](../../../protocol/discovery.md)。
public enum TXTRecord {
    public static let serviceType = "_meshdrop._tcp"

    public static func encode(
        identity: Identity,
        displayName: String,
        os: DeviceOS,
        model: String?,
        port: UInt16,
        protocolVersion: UInt8 = 1
    ) -> NWTXTRecord {
        var record = NWTXTRecord()
        record["v"] = String(protocolVersion)
        record["id"] = identity.id
        record["name"] = base64URLEncode(displayName.data(using: .utf8) ?? Data())
        record["os"] = os.rawValue
        if let model { record["model"] = model }
        record["fp"] = identity.fingerprint
        record["port"] = String(port)
        return record
    }

    /// 解析 TXT。任何必选字段缺失或格式错误返回 nil（调用方应当忽略此服务，
    /// 不能视为协议错误 — 同网段可能存在新版本广告的旧端解析不了的字段）。
    public static func decode(_ record: NWTXTRecord) -> Device? {
        guard let v = record["v"], let versionInt = UInt8(v),
              let id = record["id"], id.count == 32,
              let nameB64 = record["name"],
              let nameData = base64URLDecode(nameB64),
              let name = String(data: nameData, encoding: .utf8),
              let osStr = record["os"], let os = DeviceOS(rawValue: osStr),
              let fp = record["fp"], fp.count == 32,
              let portStr = record["port"], let port = UInt16(portStr)
        else {
            return nil
        }
        return Device(
            id: id,
            name: name,
            os: os,
            model: record["model"],
            fingerprint: fp,
            port: port,
            protocolVersion: versionInt
        )
    }

    // MARK: - base64url (no padding)

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64URLDecode(_ string: String) -> Data? {
        var s = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let pad = (4 - s.count % 4) % 4
        s.append(String(repeating: "=", count: pad))
        return Data(base64Encoded: s)
    }
}
