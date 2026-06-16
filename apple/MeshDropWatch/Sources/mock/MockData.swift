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
    /// 演示数据语言跟随 app 实际本地化（zh-Hans / en），与其它端截图保持一致。
    private static var zh: Bool {
        (Bundle.main.preferredLocalizations.first ?? "en").lowercased().hasPrefix("zh")
    }

    static var devices: [MockDevice] {
        [
            MockDevice(id: "lily",   name: "Lily's MacBook",                       who: zh ? "李莉" : "Lily",    kind: "mac",     os: "macOS",  rtt: 18, initials: "LL", color: Color(red: 1.00, green: 0.70, blue: 0.63), angle: 35,  dist: 0.55),
            MockDevice(id: "kun",    name: zh ? "Kun · Pixel 8" : "Marco · Pixel 8",    who: zh ? "坤" : "Marco",     kind: "android", os: "Pixel",  rtt: 32, initials: "M",  color: Color(red: 0.72, green: 0.90, blue: 0.78), angle: 110, dist: 0.78),
            MockDevice(id: "jiawei", name: zh ? "Jiawei · iPad" : "Ethan · iPad",       who: zh ? "嘉伟" : "Ethan",   kind: "ipad",    os: "iPadOS", rtt: 14, initials: "ET", color: Color(red: 0.78, green: 0.72, blue: 1.00), angle: 200, dist: 0.40),
            MockDevice(id: "mengxi", name: zh ? "Meng Xi · iPhone" : "Sophia · iPhone", who: zh ? "孟茜" : "Sophia",  kind: "ios",     os: "iOS",    rtt: 26, initials: "SO", color: Color(red: 1.00, green: 0.85, blue: 0.44), angle: 265, dist: 0.62),
            MockDevice(id: "dev01",  name: "DEV-01 · Win 11",                      who: zh ? "工位机" : "DEV-01", kind: "win",     os: "Win 11", rtt: 41, initials: "D1", color: Color(red: 0.60, green: 0.82, blue: 1.00), angle: 320, dist: 0.88),
        ]
    }

    static var pendingOffer: MockFileOffer {
        MockFileOffer(
            peer: zh ? "李莉" : "Lily",
            deviceName: "Lily's MacBook",
            fileName: zh ? "规划文档_v0.3.pages" : "plan_v0.3.pages",
            fileSize: "3.4 MB",
            ext: "pages",
            note: zh ? "改完了帮我看下 §2.3 那段" : "Done — take a look at §2.3",
            receivedAt: zh ? "刚刚" : "now"
        )
    }

    static var runningTransfer: MockTransfer {
        MockTransfer(
            id: "t1",
            name: "iOS-mocks-final.zip",
            size: "48.6 MB",
            ext: "zip",
            direction: .outgoing,
            peer: zh ? "孟茜" : "Sophia",
            progress: 67,
            speed: "8.4 MB/s",
            eta: "00:02",
            state: .sending
        )
    }
}
