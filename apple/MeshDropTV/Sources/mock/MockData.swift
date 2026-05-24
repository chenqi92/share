import SwiftUI

/// 直接搬 COMMON §9 的 mock 数据到 Swift。tvOS 端只接收，所以本机就是这台电视。
enum DeviceKind: String {
    case mac, ios, ipad, android, win, tv
}

struct MeshDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let who: String
    let kind: DeviceKind
    let dist: Double   // 0..1，雷达半径比
    let angle: Double  // 极坐标角度（度，0=右）
    let color: Color
    let initials: String
    let os: String
    let rtt: Int       // ms
}

enum MockData {
    static let me = (
        deviceName: "Living Room TV",
        who: "客厅电视",
        fingerprintShort: "ZX8K · L72M · 9FQ3 · 7HD2",
        fingerprintFull:  "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
        ip: "192.168.1.42",
        visibility: "客厅可见"
    )

    static let pairingCode = "LR · 4K7M"

    static let devices: [MeshDevice] = [
        .init(id: "lily",   name: "Lily's MacBook",  who: "李莉",   kind: .mac,
              dist: 0.55, angle: 35,  color: Color(red: 1.00, green: 0.71, blue: 0.63),
              initials: "LL", os: "macOS",  rtt: 18),
        .init(id: "kun",    name: "Kun · Pixel 8",   who: "坤",     kind: .android,
              dist: 0.78, angle: 110, color: Color(red: 0.72, green: 0.90, blue: 0.78),
              initials: "K",  os: "Pixel",  rtt: 32),
        .init(id: "jiawei", name: "Jiawei · iPad",   who: "嘉伟",   kind: .ipad,
              dist: 0.40, angle: 200, color: Color(red: 0.78, green: 0.72, blue: 1.00),
              initials: "JW", os: "iPadOS", rtt: 14),
        .init(id: "mengxi", name: "Meng Xi · iPhone",who: "孟茜",   kind: .ios,
              dist: 0.62, angle: 265, color: Color(red: 1.00, green: 0.85, blue: 0.44),
              initials: "MX", os: "iOS",    rtt: 26),
        .init(id: "dev01",  name: "DEV-01 · Win 11", who: "工位机", kind: .win,
              dist: 0.88, angle: 320, color: Color(red: 0.60, green: 0.82, blue: 1.00),
              initials: "D1", os: "Win 11", rtt: 41),
    ]

    /// Receive 页：当前正在传过来的一组照片
    struct IncomingPhoto: Identifiable, Hashable {
        let id: Int
        let hue: Double      // 0..1 给假地平线占位染色
        let label: String    // "1 / 18"
    }
    static let incomingPhotos: [IncomingPhoto] = (1...9).map {
        IncomingPhoto(id: $0,
                      hue: Double($0) / 18.0,
                      label: "\($0) / 18")
    }

    static let incomingFromIndex = 1  // 当前聚焦的缩略图序号
    static let incomingPeer = devices.first { $0.id == "mengxi" }!
    static let incomingFileName  = "团建相册.zip"
    static let incomingFileBytes = "128 MB · 18 张"
    static let incomingFileExt   = "HEIC"

    /// Gallery 页：已收件
    struct GalleryItem: Identifiable, Hashable {
        let id: Int
        let kind: String      // "image" / "file" / "text"
        let title: String
        let sub: String
        let hue: Double
        let ext: String?
        let badge: String?    // 比如 "18 张"
    }
    static let gallery: [GalleryItem] = [
        .init(id: 1, kind: "image", title: "团建相册",          sub: "孟茜 · 14:18 · 18 张",  hue: 0.55, ext: nil,    badge: "18"),
        .init(id: 2, kind: "file",  title: "设计稿_v3_final",   sub: "孟茜 · 14:10 · 14.2 MB", hue: 0.10, ext: "FIG",  badge: nil),
        .init(id: 3, kind: "image", title: "周末郊游",          sub: "坤 · 13:58 · 36 张",     hue: 0.32, ext: nil,    badge: "36"),
        .init(id: 4, kind: "file",  title: "iOS-mocks-final",   sub: "嘉伟 · 13:42 · 48.6 MB", hue: 0.74, ext: "ZIP",  badge: nil),
        .init(id: 5, kind: "image", title: "新家装修",          sub: "李莉 · 11:09 · 24 张",   hue: 0.04, ext: nil,    badge: "24"),
        .init(id: 6, kind: "file",  title: "spec_PRD_2026Q1",   sub: "嘉伟 · 10:22 · 2.1 MB",  hue: 0.85, ext: "PDF",  badge: nil),
        .init(id: 7, kind: "image", title: "宝宝出生",          sub: "李莉 · 昨天 · 12 张",    hue: 0.93, ext: nil,    badge: "12"),
        .init(id: 8, kind: "image", title: "演唱会现场",        sub: "坤 · 昨天 · 9 张",       hue: 0.40, ext: nil,    badge: "9"),
        .init(id: 9, kind: "file",  title: "release-notes",     sub: "DEV-01 · 昨天 · 4.8 KB", hue: 0.62, ext: "MD",   badge: nil),
        .init(id: 10, kind: "image", title: "演讲花絮",         sub: "孟茜 · 周一 · 7 张",     hue: 0.50, ext: nil,    badge: "7"),
    ]

    static let gallerySummary = (count: "124", size: "14.2 GB")

    /// 设置页面：当前值
    static let settings = (
        displayName: "Living Room TV",
        savePath: "本机相册 · NAS://meshdrop-tv/inbox",
        autoAccept: "仅信任设备",
        network: "Wi-Fi · LAN ONLY · 192.168.1.42",
        screensaver: "10 分钟后进入幻灯片"
    )
}
