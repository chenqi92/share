import SwiftUI

// COMMON §9 view DTO 类型定义。这些 `Mock*` 类型在 runtime 由 ShareEngine 模型经
// EngineProjection adapter 投影出来，供 SwiftUI 复用。
//
// 静态 sample 数据（设备 / 历史 / 配对 / clipboard 等）拆到 MockData+Sample.swift，
// 整个文件 #if DEBUG 围起来，release build 不带 —— 避免假名 / 假 IP 出现在线上 binary。

// MARK: - 设备

public enum MockDeviceKind: String, CaseIterable, Sendable {
    case mac, win, ipad, ios, android, linux
}

public struct MockDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let who: String           // 中文姓名
    public let kind: MockDeviceKind
    public let dist: Double          // 0...1，雷达距离
    public let angle: Double         // 度，雷达角度
    public let colorHex: UInt32
    public let initials: String
    public let os: String
    public let rtt: Int              // ms
    public let isOnline: Bool

    public var color: Color {
        Color(red: Double((colorHex >> 16) & 0xFF) / 255,
              green: Double((colorHex >> 8) & 0xFF) / 255,
              blue: Double(colorHex & 0xFF) / 255)
    }
}

/// Sample data 命名空间。所有数据字段实装在 MockData+Sample.swift（#if DEBUG）。
public enum Mock {}

public struct MockMe: Sendable {
    public let name: String
    public let fingerprint: String
    public let ip: String
    public let os: String
    public let visibility: String
}

// MARK: - 历史 / 对话流

public enum MockKind: String, Sendable { case text, file, image }
public enum MockDir: String, Sendable { case incoming, outgoing }
public enum MockStatus: String, Sendable { case done, transferring, queued, failed }

public struct MockHistoryItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let dir: MockDir
    public let peer: String
    public let time: String
    public let kind: MockKind
    public let count: Int?        // image grid 张数
    public let name: String?      // 文件名
    public let size: String?
    public let ext: String?
    public let content: String?   // text
    public let progress: Int?     // 0-100
    public let status: MockStatus
}

// MARK: - 对话单条消息

public struct MockMessage: Identifiable, Hashable, Sendable {
    public let id: String
    public let dir: MockDir
    public let kind: MockKind
    public let text: String?
    public let time: String
    public let fileName: String?
    public let fileSize: String?
    public let fileExt: String?
    public let imageCount: Int?
    public let delivered: Bool
}

// MARK: - 配对待审

public struct MockPendingPairing: Sendable {
    public let id: String
    public let peer: String
    public let deviceName: String
    public let fingerprint: String     // 4 字符 8 组
    public let receivedAt: String
}

// MARK: - 待审文件 offer

public struct MockPendingOffer: Sendable {
    public let id: String
    public let peer: String
    public let deviceName: String
    public let fileName: String
    public let fileSize: String
    public let note: String?           // 文字便签
    public let receivedAt: String
}

// MARK: - 剪贴板

public enum MockClipKind: String, Sendable { case link, text, code }

public struct MockClipboardItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let who: String
    public let kind: MockClipKind
    public let body: String
    public let lang: String?
    public let ago: String
}

// MARK: - 传输任务

public struct MockTransfer: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let size: String
    public let ext: String
    public let from: String
    public let to: String
    public let progress: Int        // 0-100
    public let state: MockStatus
    public let direction: MockDir   // sending=outgoing, receiving=incoming
    public let speed: String?
    public let eta: String?
    /// 失败原因（校验失败 / 连接中断 / 对方拒收 …），仅 state == .failed 时有值。
    public var failReason: String? = nil
}

// MARK: - Trust Manager

public struct MockTrustedPeer: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let device: String
    public let fingerprint: String
    public let firstSeen: String
    public let lastSeen: String
}
