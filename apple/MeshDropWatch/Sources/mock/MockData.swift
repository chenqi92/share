import SwiftUI

struct MockDevice: Identifiable, Hashable {
    let id: String
    let name: String
    let who: String
    let kind: String
    let os: String
    let rtt: Int
    let initials: String
    let color: Color
    let angle: Double
    let dist: Double
}

struct MockFileOffer {
    let peer: String
    let deviceName: String
    let fileName: String
    let fileSize: String
    let ext: String
    let note: String
    let receivedAt: String
}

struct MockTransfer: Identifiable {
    let id: String
    let name: String
    let size: String
    let ext: String
    let direction: Direction
    let peer: String
    let progress: Int
    let speed: String?
    let eta: String?
    let state: State

    enum Direction { case incoming, outgoing }
    enum State { case sending, receiving, done, queued, failed }
}

enum Mock {
    static let devices: [MockDevice] = [
        MockDevice(id: "lily",   name: "Lily · MacBook",   who: "李莉",   kind: "mac",     os: "macOS",  rtt: 18, initials: "LL", color: Color(red: 1.00, green: 0.70, blue: 0.63), angle: 35,  dist: 0.55),
        MockDevice(id: "kun",    name: "Kun · Pixel 8",    who: "坤",     kind: "android", os: "Pixel",  rtt: 32, initials: "K",  color: Color(red: 0.72, green: 0.90, blue: 0.78), angle: 110, dist: 0.78),
        MockDevice(id: "jiawei", name: "Jiawei · iPad",    who: "嘉伟",   kind: "ipad",    os: "iPadOS", rtt: 14, initials: "JW", color: Color(red: 0.78, green: 0.72, blue: 1.00), angle: 200, dist: 0.40),
        MockDevice(id: "mengxi", name: "Meng Xi · iPhone", who: "孟茜",   kind: "ios",     os: "iOS",    rtt: 26, initials: "MX", color: Color(red: 1.00, green: 0.85, blue: 0.44), angle: 265, dist: 0.62),
        MockDevice(id: "dev01",  name: "DEV-01 · Win 11",  who: "工位机", kind: "win",     os: "Win 11", rtt: 41, initials: "D1", color: Color(red: 0.60, green: 0.82, blue: 1.00), angle: 320, dist: 0.88),
    ]

    static let pendingOffer = MockFileOffer(
        peer: "李莉",
        deviceName: "Lily · MacBook",
        fileName: "规划文档_v0.3.pages",
        fileSize: "3.4 MB",
        ext: "pages",
        note: "改完了帮我看下 §2.3 那段",
        receivedAt: "刚刚"
    )

    static let runningTransfer = MockTransfer(
        id: "t1",
        name: "iOS-mocks-final.zip",
        size: "48.6 MB",
        ext: "zip",
        direction: .outgoing,
        peer: "孟茜",
        progress: 67,
        speed: "8.4 MB/s",
        eta: "00:02",
        state: .sending
    )
}
