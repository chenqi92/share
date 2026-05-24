import SwiftUI

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

public enum Mock {
    public static let devices: [MockDevice] = [
        .init(id: "lily",   name: "Lily's MacBook",   who: "李莉",   kind: .mac,     dist: 0.55, angle: 35,  colorHex: 0xFFB4A1, initials: "LL", os: "macOS",  rtt: 18, isOnline: true),
        .init(id: "kun",    name: "Kun · Pixel 8",    who: "坤",     kind: .android, dist: 0.78, angle: 110, colorHex: 0xB7E5C8, initials: "K",  os: "Pixel",  rtt: 32, isOnline: true),
        .init(id: "jiawei", name: "Jiawei · iPad",    who: "嘉伟",   kind: .ipad,    dist: 0.40, angle: 200, colorHex: 0xC7B8FF, initials: "JW", os: "iPadOS", rtt: 14, isOnline: true),
        .init(id: "mengxi", name: "Meng Xi · iPhone", who: "孟茜",   kind: .ios,     dist: 0.62, angle: 265, colorHex: 0xFFD970, initials: "MX", os: "iOS",    rtt: 26, isOnline: true),
        .init(id: "dev01",  name: "DEV-01 · Win 11",  who: "工位机", kind: .win,     dist: 0.88, angle: 320, colorHex: 0x9AD0FF, initials: "D1", os: "Win 11", rtt: 41, isOnline: false),
    ]

    public static let me = MockMe(
        name: "我的 iPhone",
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2",
        ip: "192.168.1.42",
        os: "iOS 26",
        visibility: "可见"
    )
}

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

extension Mock {
    public static let history: [MockHistoryItem] = [
        .init(id: "h6", dir: .incoming, peer: "孟茜", time: "14:18", kind: .image,
              count: 2, name: nil, size: nil, ext: nil, content: nil, progress: nil, status: .done),
        .init(id: "h5", dir: .outgoing, peer: "孟茜", time: "14:10", kind: .file,
              count: nil, name: "设计稿_v3_final.fig", size: "14.2 MB", ext: "fig", content: nil, progress: nil, status: .done),
        .init(id: "h4", dir: .outgoing, peer: "李莉", time: "14:09", kind: .text,
              count: nil, name: nil, size: nil, ext: nil, content: "改完了，整理一下发你", progress: nil, status: .done),
        .init(id: "h3", dir: .outgoing, peer: "嘉伟", time: "14:08", kind: .file,
              count: nil, name: "iOS-mocks-final.zip", size: "48.6 MB", ext: "zip", content: nil, progress: 67, status: .transferring),
        .init(id: "h2", dir: .incoming, peer: "坤", time: "13:58", kind: .file,
              count: nil, name: "IMG_4821~38.heic", size: "128 MB", ext: "heic", content: nil, progress: 12, status: .transferring),
        .init(id: "h1", dir: .outgoing, peer: "李莉", time: "13:42", kind: .file,
              count: nil, name: "demo-video.mp4", size: "512 MB", ext: "mp4", content: nil, progress: 0, status: .queued),
    ]
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

extension Mock {
    /// 当前与孟茜的对话流（按时间正序）。
    public static let chatWithMengxi: [MockMessage] = [
        .init(id: "m1", dir: .outgoing, kind: .text,
              text: "嘉伟说图改完了，我转给你看下", time: "14:06",
              fileName: nil, fileSize: nil, fileExt: nil, imageCount: nil, delivered: true),
        .init(id: "m2", dir: .outgoing, kind: .file,
              text: nil, time: "14:06",
              fileName: "规划文档_v0.3.pages", fileSize: "3.4 MB", fileExt: "pages",
              imageCount: nil, delivered: true),
        .init(id: "m3", dir: .incoming, kind: .text,
              text: "收到，下午开会前给反馈", time: "14:07",
              fileName: nil, fileSize: nil, fileExt: nil, imageCount: nil, delivered: false),
        .init(id: "m4", dir: .incoming, kind: .image,
              text: nil, time: "14:08",
              fileName: nil, fileSize: nil, fileExt: nil, imageCount: 3, delivered: false),
        .init(id: "m5", dir: .incoming, kind: .text,
              text: "这几张供参考", time: "14:08",
              fileName: nil, fileSize: nil, fileExt: nil, imageCount: nil, delivered: false),
        .init(id: "m6", dir: .outgoing, kind: .text,
              text: "好，第二章 §2.3 那段我再读一遍 ", time: "14:09",
              fileName: nil, fileSize: nil, fileExt: nil, imageCount: nil, delivered: true),
    ]
}

// MARK: - 配对待审

public struct MockPendingPairing: Sendable {
    public let id: String
    public let peer: String
    public let deviceName: String
    public let fingerprint: String     // 4 字符 8 组
    public let receivedAt: String
}

extension Mock {
    public static let pendingPairing = MockPendingPairing(
        id: "pp-1",
        peer: "李莉",
        deviceName: "Lily's MacBook",
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
        receivedAt: "8s ago"
    )
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

extension Mock {
    public static let pendingOffer = MockPendingOffer(
        id: "po-1",
        peer: "嘉伟",
        deviceName: "Jiawei · iPad",
        fileName: "规划文档_v0.3.pages",
        fileSize: "3.4 MB",
        note: "改完了帮我看下第二章，特别是 §2.3 那段",
        receivedAt: "just now"
    )
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

extension Mock {
    public static let clipboard: [MockClipboardItem] = [
        .init(id: "cb1", who: "嘉伟", kind: .link, body: "https://internal.acme.io/specs/auth-v3", lang: nil, ago: "8s"),
        .init(id: "cb2", who: "孟茜", kind: .text, body: "1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配", lang: nil, ago: "12m"),
        .init(id: "cb3", who: "李莉", kind: .code, body: "docker run --rm -v $PWD:/app meshdrop/build:latest", lang: "sh", ago: "34m"),
        .init(id: "cb4", who: "坤", kind: .text, body: "会议室 B 已订到 16:00–17:30", lang: nil, ago: "1h"),
        .init(id: "cb5", who: "我", kind: .link, body: "figma://file/Q8xK2/MeshDrop?node-id=42:108", lang: nil, ago: "2h"),
    ]
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
}

extension Mock {
    public static let transfers: [MockTransfer] = [
        .init(id: "t1", name: "设计稿_v3_final.fig",   size: "14.2 MB", ext: "fig",
              from: "我", to: "孟茜",   progress: 100, state: .done,         direction: .outgoing, speed: nil,         eta: "00:08"),
        .init(id: "t2", name: "iOS-mocks-final.zip",    size: "48.6 MB", ext: "zip",
              from: "我", to: "孟茜",   progress: 67,  state: .transferring, direction: .outgoing, speed: "8.4 MB/s",  eta: "00:02"),
        .init(id: "t3", name: "spec_PRD_2026Q1.pdf",    size: "2.1 MB",  ext: "pdf",
              from: "我", to: "嘉伟",   progress: 34,  state: .transferring, direction: .outgoing, speed: "3.1 MB/s",  eta: "00:01"),
        .init(id: "t4", name: "IMG_4821~IMG_4838.heic", size: "128 MB · 18 张", ext: "heic",
              from: "坤", to: "我",     progress: 12,  state: .transferring, direction: .incoming, speed: "11.7 MB/s", eta: "00:09"),
        .init(id: "t5", name: "release-notes.md",       size: "4.8 KB",  ext: "md",
              from: "我", to: "DEV-01", progress: 100, state: .done,         direction: .outgoing, speed: nil,         eta: "00:01"),
        .init(id: "t6", name: "demo-video.mp4",         size: "512 MB",  ext: "mp4",
              from: "我", to: "李莉",   progress: 0,   state: .queued,       direction: .outgoing, speed: nil,         eta: nil),
    ]
}

// MARK: - 速度图采样

extension Mock {
    public static let uploadBars:   [Int] = [3,5,8,7,9,6,11,12,14,11,10,11,12,11]
    public static let downloadBars: [Int] = [8,9,7,6,5,7,10,12,11,12,11,12,11,12]
    public static let sessionBars:  [Int] = [2,3,5,4,6,8,7,9,10,12,11,12,11,12,14]
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

extension Mock {
    public static let trusted: [MockTrustedPeer] = [
        .init(id: "tp1", name: "李莉",   device: "Lily's MacBook",   fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2", firstSeen: "2026-04-12", lastSeen: "刚刚"),
        .init(id: "tp2", name: "嘉伟",   device: "Jiawei · iPad",    fingerprint: "M1P6 · QA8N · KZ9R · X3WF", firstSeen: "2026-04-12", lastSeen: "刚刚"),
        .init(id: "tp3", name: "孟茜",   device: "Meng Xi · iPhone", fingerprint: "8KAR · L9NY · QX2W · M3ZP", firstSeen: "2026-04-20", lastSeen: "8 分钟前"),
        .init(id: "tp4", name: "坤",     device: "Kun · Pixel 8",    fingerprint: "P7QM · Z3LK · X8NR · 92AW", firstSeen: "2026-05-01", lastSeen: "1 小时前"),
        .init(id: "tp5", name: "工位机", device: "DEV-01 · Win 11",  fingerprint: "WL92 · QM3K · NX7P · 8ARZ", firstSeen: "2026-05-10", lastSeen: "昨天"),
    ]
}
