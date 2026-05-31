import Foundation
import SwiftUI

// MARK: ─── 设备 ─────────────────────────────────────────
//
// 这里的 `Mock*` 类型 (`MockDevice`, `MockHistory`, etc.) 是 view DTO，runtime 由
// `ShareEngine` 模型经 adapter 投影成这些 record，给 SwiftUI 复用。
// `static let all` 等静态数据数组仅供 Xcode Preview / 离线截图用 —— 已用 `#if DEBUG`
// 围起来，release build 不含；运行时的数据全部来自 engine。

enum DeviceKind: String, CaseIterable {
    case mac, win, ios, android, ipad
}

struct MockDevice: Identifiable, Hashable {
    let id: String
    let name: String          // "Lily's MacBook"
    let who: String           // "李莉"
    let kind: DeviceKind
    let dist: Double          // 雷达半径 0-1
    let angle: Double         // 角度 0-360
    let color: Color          // initials 圆形彩色背景
    let initials: String      // "LL"
    let os: String            // "macOS"
    let rtt: Int              // ms
    let online: Bool

#if DEBUG
    static let all: [MockDevice] = [
        .init(id: "lily",    name: "Lily's MacBook",   who: "李莉",   kind: .mac,     dist: 0.55, angle: 35,  color: Color(hex: 0xFFB4A1), initials: "LL", os: "macOS",  rtt: 18, online: true),
        .init(id: "kun",     name: "Kun · Pixel 8",    who: "坤",     kind: .android, dist: 0.78, angle: 110, color: Color(hex: 0xB7E5C8), initials: "K",  os: "Pixel",  rtt: 32, online: true),
        .init(id: "jiawei",  name: "Jiawei · iPad",    who: "嘉伟",   kind: .ipad,    dist: 0.40, angle: 200, color: Color(hex: 0xC7B8FF), initials: "JW", os: "iPadOS", rtt: 14, online: true),
        .init(id: "mengxi",  name: "Meng Xi · iPhone", who: "孟茜",   kind: .ios,     dist: 0.62, angle: 265, color: Color(hex: 0xFFD970), initials: "MX", os: "iOS",    rtt: 26, online: true),
        .init(id: "dev01",   name: "DEV-01 · Win 11",  who: "工位机", kind: .win,     dist: 0.88, angle: 320, color: Color(hex: 0x9AD0FF), initials: "D1", os: "Win 11", rtt: 41, online: true),
    ]
#endif
}

// MARK: ─── 历史 ─────────────────────────────────────────

enum HistoryDir { case incoming, outgoing }
enum HistoryKind: String { case image, file, text }
enum HistoryStatus: String { case done, transferring, queued, failed }

struct MockHistory: Identifiable {
    let id: String
    let dir: HistoryDir
    let peer: String
    let time: String
    let kind: HistoryKind
    var name: String? = nil
    var size: String? = nil
    var ext: String? = nil
    var fileURL: URL? = nil
    var content: String? = nil
    var count: Int? = nil
    var progress: Int? = nil
    let status: HistoryStatus

#if DEBUG
    static let all: [MockHistory] = [
        .init(id: "h6", dir: .incoming, peer: "孟茜", time: "14:18", kind: .image,                                                        count: 2,            status: .done),
        .init(id: "h5", dir: .outgoing, peer: "孟茜", time: "14:10", kind: .file,  name: "设计稿_v3_final.fig",     size: "14.2 MB", ext: "fig",                       status: .done),
        .init(id: "h4", dir: .outgoing, peer: "李莉", time: "14:09", kind: .text,                                                                 content: "改完了，整理一下发你 👇", status: .done),
        .init(id: "h3", dir: .outgoing, peer: "嘉伟", time: "14:08", kind: .file,  name: "iOS-mocks-final.zip",    size: "48.6 MB", ext: "zip", progress: 67,           status: .transferring),
        .init(id: "h2", dir: .incoming, peer: "坤",   time: "13:58", kind: .file,  name: "IMG_4821~38.heic",       size: "128 MB",  ext: "heic", progress: 12,          status: .transferring),
        .init(id: "h1", dir: .outgoing, peer: "李莉", time: "13:42", kind: .file,  name: "demo-video.mp4",         size: "512 MB",  ext: "mp4",                         status: .queued),
    ]
#endif
}

// MARK: ─── 待审 ─────────────────────────────────────────

struct MockPendingPairing {
    let id: String
    let peer: String
    let deviceName: String
    let fingerprint: String
    let receivedAt: String

    static let sample = MockPendingPairing(
        id: "pp-1",
        peer: "李莉",
        deviceName: "Lily's MacBook",
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
        receivedAt: "8s ago"
    )
}

struct MockPendingOffer {
    let id: String
    let peer: String
    let deviceName: String
    let fileName: String
    let fileSize: String
    var isImage: Bool = false
    var previewBase64: String? = nil
    let note: String
    let receivedAt: String

    static let sample = MockPendingOffer(
        id: "po-1",
        peer: "嘉伟",
        deviceName: "Jiawei · iPad",
        fileName: "规划文档_v0.3.pages",
        fileSize: "3.4 MB",
        note: "改完了帮我看下第二章，特别是 §2.3 那段",
        receivedAt: "刚刚"
    )
}

// MARK: ─── 剪贴板 ───────────────────────────────────────

enum ClipKind: String { case link, text, code }

struct MockClip: Identifiable {
    let id: String
    let who: String
    let kind: ClipKind
    let body: String
    let lang: String?
    let ago: String

#if DEBUG
    static let all: [MockClip] = [
        .init(id: "cb1", who: "嘉伟", kind: .link, body: "https://internal.acme.io/specs/auth-v3", lang: nil, ago: "8s"),
        .init(id: "cb2", who: "孟茜", kind: .text, body: "1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配", lang: nil, ago: "12m"),
        .init(id: "cb3", who: "李莉", kind: .code, body: "docker run --rm -v $PWD:/app meshdrop/build:latest", lang: "sh", ago: "34m"),
        .init(id: "cb4", who: "坤",   kind: .text, body: "会议室 B 已订到 16:00–17:30", lang: nil, ago: "1h"),
        .init(id: "cb5", who: "我",   kind: .link, body: "figma://file/Q8xK2/MeshDrop?node-id=42:108", lang: nil, ago: "2h"),
    ]
#endif
}

// MARK: ─── 传输 ─────────────────────────────────────────

enum TransferState: String { case sending, receiving, done, queued, failed }

struct MockTransfer: Identifiable {
    // 真实数据投影时传入 history.id；MockData preview 自动给新 UUID
    var id: UUID = UUID()
    let name: String
    let size: String
    let ext: String
    let from: String
    let to: String
    let progress: Int
    let state: TransferState
    let speed: String?
    let eta: String?
    /// 失败原因（校验失败 / 连接中断 / 对方拒收 …），仅 state == .failed 时有值。
    var failReason: String? = nil

#if DEBUG
    static let all: [MockTransfer] = [
        .init(name: "设计稿_v3_final.fig",     size: "14.2 MB",          ext: "fig",  from: "我", to: "孟茜",  progress: 100, state: .done,      speed: nil,            eta: "00:08"),
        .init(name: "iOS-mocks-final.zip",     size: "48.6 MB",          ext: "zip",  from: "我", to: "孟茜",  progress: 67,  state: .sending,   speed: "8.4 MB/s",      eta: "00:02"),
        .init(name: "spec_PRD_2026Q1.pdf",     size: "2.1 MB",           ext: "pdf",  from: "我", to: "嘉伟",  progress: 34,  state: .sending,   speed: "3.1 MB/s",      eta: "00:01"),
        .init(name: "IMG_4821~IMG_4838.heic",  size: "128 MB · 18 张",   ext: "heic", from: "坤", to: "我",    progress: 12,  state: .receiving, speed: "11.7 MB/s",     eta: "00:09"),
        .init(name: "release-notes.md",        size: "4.8 KB",           ext: "md",   from: "我", to: "DEV-01", progress: 100, state: .done,     speed: nil,            eta: "00:01"),
        .init(name: "demo-video.mp4",          size: "512 MB",           ext: "mp4",  from: "我", to: "李莉",  progress: 0,   state: .queued,    speed: nil,            eta: nil),
    ]
#endif
}

// MARK: ─── 速度 ─────────────────────────────────────────

enum MockSpeed {
    static let uploadBars:   [Int] = [3, 5, 8, 7, 9, 6, 11, 12, 14, 11, 10, 11, 12, 11]
    static let downloadBars: [Int] = [8, 9, 7, 6, 5, 7, 10, 12, 11, 12, 11, 12, 11, 12]
    static let sessionBars:  [Int] = [2, 3, 5, 4, 6, 8, 7, 9, 10, 12, 11, 12, 11, 12, 14]
}

// MARK: ─── 本机 ─────────────────────────────────────────

struct MockMe {
    static let name = "我"
    static let deviceName = "This MacBook"
    static let fingerprint = "ZX8K · L72M · 9FQ3 · 7HD2"
    static let fullFingerprint = "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF"
    static let ip = "192.168.1.42"
    static let os = "macOS"
    static let visibility = "可见 · Visible · LAN"
}

// MARK: ─── 配对设备表 ───────────────────────────────────

struct MockTrustedDevice: Identifiable {
    let id: String
    let name: String
    let who: String
    let kind: DeviceKind
    let fingerprint: String
    let pairedAt: String
    let lastSeen: String
    let online: Bool

#if DEBUG
    static let all: [MockTrustedDevice] = [
        .init(id: "t1", name: "Lily's MacBook",   who: "李莉", kind: .mac,     fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2", pairedAt: "2026-04-12", lastSeen: "刚刚",       online: true),
        .init(id: "t2", name: "Meng Xi · iPhone", who: "孟茜", kind: .ios,     fingerprint: "P4R7 · KQ2X · L9MN · 7CA1", pairedAt: "2026-03-28", lastSeen: "刚刚",       online: true),
        .init(id: "t3", name: "Jiawei · iPad",    who: "嘉伟", kind: .ipad,    fingerprint: "9HX2 · BNT4 · LM7Q · K3FZ", pairedAt: "2026-03-11", lastSeen: "刚刚",       online: true),
        .init(id: "t4", name: "Kun · Pixel 8",    who: "坤",   kind: .android, fingerprint: "C8YR · NMP3 · X1QK · L8H9", pairedAt: "2026-02-17", lastSeen: "2 天前",    online: false),
        .init(id: "t5", name: "DEV-01 · Win 11",  who: "工位机", kind: .win,   fingerprint: "T2W8 · KR5N · MX9P · BLH6", pairedAt: "2026-01-09", lastSeen: "刚刚",       online: true),
        .init(id: "t6", name: "MBP-2019",         who: "我",   kind: .mac,     fingerprint: "QZ7X · 8RTM · K3PN · 9LWY", pairedAt: "2025-11-22", lastSeen: "5 天前",    online: false),
    ]
#endif
}
