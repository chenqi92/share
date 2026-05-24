import Foundation

public enum DeviceOS: String, Codable, Sendable, CaseIterable {
    case ios, android, macos, windows, linux

    public static var current: DeviceOS {
        #if os(macOS)
        return .macos
        #elseif os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
        // 协议 v1 的 os 枚举只有 ios/android/macos/windows/linux；
        // tvOS/visionOS/watchOS 暂时统一以 .ios 广告（model 字段携带真实机型）。
        return .ios
        #else
        return .linux
        #endif
    }
}

public struct Device: Identifiable, Hashable, Sendable {
    public let id: String              // 32 hex
    public var name: String            // 已 base64url 解码后的 UTF-8
    public var os: DeviceOS
    public var model: String?
    public var fingerprint: String     // 32 hex
    public var port: UInt16
    public var protocolVersion: UInt8

    public init(
        id: String,
        name: String,
        os: DeviceOS,
        model: String? = nil,
        fingerprint: String,
        port: UInt16,
        protocolVersion: UInt8 = 1
    ) {
        self.id = id
        self.name = name
        self.os = os
        self.model = model
        self.fingerprint = fingerprint
        self.port = port
        self.protocolVersion = protocolVersion
    }

    /// 人眼对齐用：把 32 hex 指纹切成 8 组 4 位、空格分隔、全大写。
    public var humanFingerprint: String {
        let upper = fingerprint.uppercased()
        var out: [String] = []
        var idx = upper.startIndex
        while idx < upper.endIndex {
            let end = upper.index(idx, offsetBy: 4, limitedBy: upper.endIndex) ?? upper.endIndex
            out.append(String(upper[idx..<end]))
            idx = end
        }
        return out.joined(separator: " ")
    }
}
