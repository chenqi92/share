import SwiftUI

/// COMMON §9 mock 数据的 Swift 化。本轮全部 UI 由这份常量驱动，不接 backend。
enum MeshDropKind: String, Hashable {
    case mac, win, ipad, ios, android
    var glyph: String {
        switch self {
        case .mac:     return "□"
        case .win:     return "▦"
        case .ipad:    return "▭"
        case .ios:     return "❘"
        case .android: return "❘"
        }
    }
    var label: String {
        switch self {
        case .mac:     return "MAC"
        case .win:     return "WIN"
        case .ipad:    return "iPAD"
        case .ios:     return "iOS"
        case .android: return "ANDROID"
        }
    }
}

struct MockDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let who: String
    let kind: MeshDropKind
    /// 0...1，等比缩放半径
    let dist: Double
    /// 极坐标角度（度）
    let angle: Double
    let color: Color
    let initials: String
    let os: String
    let rtt: Int
    /// 物理近似距离，仅 UI 显示
    let approxMeters: Double

    /// 离 viewer 远近的归一化（0 = 最近 / 1 = 最远）。
    /// SpatialNearby 用它分 near / mid / far 3 层。
    var depth: Double { dist }

    var depthLayer: DepthLayer {
        if depth < 0.55 { return .near }
        else if depth < 0.78 { return .mid }
        else { return .far }
    }
}

enum DepthLayer: String, CaseIterable {
    case near, mid, far

    /// PeerOrb 的整体缩放：near 1.0、mid 0.78、far 0.58
    var scale: Double {
        switch self {
        case .near: return 1.00
        case .mid:  return 0.78
        case .far:  return 0.58
        }
    }
    /// 远的卡片透明度衰减
    var opacity: Double {
        switch self {
        case .near: return 1.00
        case .mid:  return 0.92
        case .far:  return 0.78
        }
    }
    /// 远的卡片背后玻璃模糊（视觉景深）
    var blur: Double {
        switch self {
        case .near: return 0.0
        case .mid:  return 0.6
        case .far:  return 1.6
        }
    }
}

enum MockData {

    // MARK: 5 个设备（COMMON §9.1）
    static let devices: [MockDevice] = [
        MockDevice(id: "lily",   name: "Lily's MacBook", who: "李莉",  kind: .mac,
                   dist: 0.55, angle: 35,
                   color: Color(red: 1.0,  green: 0.71, blue: 0.63),
                   initials: "LL", os: "macOS",  rtt: 18, approxMeters: 2.4),
        MockDevice(id: "kun",    name: "Kun · Pixel 8",  who: "坤",    kind: .android,
                   dist: 0.78, angle: 110,
                   color: Color(red: 0.72, green: 0.90, blue: 0.79),
                   initials: "K",  os: "Pixel",  rtt: 32, approxMeters: 4.1),
        MockDevice(id: "jiawei", name: "Jiawei · iPad",  who: "嘉伟",  kind: .ipad,
                   dist: 0.40, angle: 200,
                   color: Color(red: 0.78, green: 0.72, blue: 1.0),
                   initials: "JW", os: "iPadOS", rtt: 14, approxMeters: 1.8),
        MockDevice(id: "mengxi", name: "Meng Xi · iPhone", who: "孟茜", kind: .ios,
                   dist: 0.62, angle: 265,
                   color: Color(red: 1.0,  green: 0.85, blue: 0.44),
                   initials: "MX", os: "iOS",    rtt: 26, approxMeters: 3.0),
        MockDevice(id: "dev01",  name: "DEV-01 · Win 11", who: "工位机", kind: .win,
                   dist: 0.88, angle: 320,
                   color: Color(red: 0.60, green: 0.82, blue: 1.0),
                   initials: "D1", os: "Win 11", rtt: 41, approxMeters: 6.8),
    ]

    static func device(_ id: String) -> MockDevice {
        devices.first { $0.id == id } ?? devices[0]
    }

    // MARK: self
    struct Me {
        let name: String
        let fingerprintShort: String
        let ip: String
        let os: String
        let visibility: String
    }
    static let me = Me(
        name: "我",
        fingerprintShort: "ZX8K · L72M · 9FQ3 · 7HD2",
        ip: "192.168.1.42",
        os: "visionOS",
        visibility: "可见"
    )

    // MARK: 待审 offer（接收弹卡用）
    struct PendingOffer: Identifiable {
        let id = "po-1"
        let peerId = "jiawei"
        let fileName = "规划文档_v0.3.pages"
        let fileSize = "3.4 MB"
        let pageCount = "12 页"
        let note  = "改完了帮我看下第二章,特别是 §2.3 那段"
        let receivedAt = "just now"
    }
    static let pendingOffer = PendingOffer()

    // MARK: 待选 payload（中央面板显示"已选 3 张照片 12.4 MB"）
    struct SelectedPayload {
        let count: Int = 3
        let kind: String = "照片"
        let totalSize: String = "12.4 MB"
        let imageHues: [Double] = [16, 220, 156]
    }
    static let selectedPayload = SelectedPayload()

    // MARK: 飞行中传输（TransfersInFlight 页用）
    struct InFlightTransfer: Identifiable, Hashable {
        let id: String
        let name: String
        let size: String
        let ext: String
        let fromId: String
        let toId: String
        /// 0...1
        let progress: Double
        let speed: String
        let eta: String
        let direction: Direction
        enum Direction { case outgoing, incoming }
    }
    static let inFlight: [InFlightTransfer] = [
        InFlightTransfer(id: "t1", name: "iOS-mocks-final.zip",
                         size: "48.6 MB", ext: "zip",
                         fromId: "me",     toId: "mengxi",
                         progress: 0.67, speed: "8.4 MB/s", eta: "00:02",
                         direction: .outgoing),
        InFlightTransfer(id: "t2", name: "spec_PRD_2026Q1.pdf",
                         size: "2.1 MB",  ext: "pdf",
                         fromId: "me",     toId: "jiawei",
                         progress: 0.34, speed: "3.1 MB/s", eta: "00:01",
                         direction: .outgoing),
        InFlightTransfer(id: "t3", name: "IMG_4821~4838.heic",
                         size: "128 MB · 18 张", ext: "heic",
                         fromId: "kun",   toId: "me",
                         progress: 0.12, speed: "11.7 MB/s", eta: "00:09",
                         direction: .incoming),
    ]

    // MARK: pairing
    struct Pairing {
        let peerId = "lily"
        /// 6 字符短码
        let shortCode = "QX-7M-93"
        let fingerprintFull = "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF"
    }
    static let pairing = Pairing()

    // MARK: conversations
    struct Conversation: Identifiable {
        let id: String
        let peerId: String
        let lastSnippet: String
        let time: String
        let unread: Int
    }
    static let conversations: [Conversation] = [
        Conversation(id: "c1", peerId: "lily",
                     lastSnippet: "改完了，整理一下发你 👇", time: "14:09", unread: 0),
        Conversation(id: "c2", peerId: "mengxi",
                     lastSnippet: "[图片 ×2]",            time: "14:18", unread: 2),
        Conversation(id: "c3", peerId: "jiawei",
                     lastSnippet: "帮我看第 3 节就行",     time: "14:08", unread: 1),
        Conversation(id: "c4", peerId: "kun",
                     lastSnippet: "会议室 B 已订到 16:00", time: "13:58", unread: 0),
    ]
}

/// 计算 PeerOrb 在屏幕坐标系的位置（以画布中心为原点）。
func peerScreenPos(for device: MockDevice, canvas: CGSize) -> CGPoint {
    // 让窗口中心 ~ 占画布中央 30~85% 半径环
    let r = min(canvas.width, canvas.height) * 0.46
    let rDevice = r * (0.40 + device.dist * 0.55) // 0.40 ~ 0.95 ring
    let rad = device.angle * .pi / 180
    return CGPoint(
        x: canvas.width  * 0.5 + cos(rad) * rDevice,
        y: canvas.height * 0.5 + sin(rad) * rDevice
    )
}
