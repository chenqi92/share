import SwiftUI
import MeshDropKit

/// 把 ShareEngine 给的 Device 投影到 tvOS 雷达 / 头像视图模型 MeshDevice。
/// dist / angle / color 用 fingerprint 派生的稳定哈希，保证同一设备每次落点一致。
enum EngineAdapters {
    static func radarDevices(from devices: [Device]) -> [MeshDevice] {
        devices.map { device(from: $0) }
    }

    static func device(from d: Device) -> MeshDevice {
        let hash = stableHash(d.id + d.fingerprint)
        let angle = Double(hash % 360)
        let dist = 0.45 + Double((hash >> 9) % 50) / 100.0   // 0.45 ~ 0.95
        return MeshDevice(
            id: d.id,
            name: d.model ?? d.name,
            who: d.name,
            kind: kind(for: d.os),
            dist: dist,
            angle: angle,
            color: palette(hash: hash),
            initials: initials(for: d.name),
            os: osLabel(for: d.os),
            rtt: 0
        )
    }

    static func kind(for os: DeviceOS) -> DeviceKind {
        switch os {
        case .ios:     return .ios
        case .macos:   return .mac
        case .android: return .android
        case .windows: return .win
        case .linux:   return .linux
        }
    }

    static func osLabel(for os: DeviceOS) -> String {
        switch os {
        case .ios:     return "iOS"
        case .macos:   return "macOS"
        case .android: return "Android"
        case .windows: return "Win"
        case .linux:   return "Linux"
        }
    }

    static func initials(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(separator: " ")
        if parts.count >= 2,
           let a = parts[0].first, let b = parts[1].first {
            return String([a, b]).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    private static func palette(hash: UInt64) -> Color {
        let colors: [Color] = [
            Color(red: 1.00, green: 0.71, blue: 0.63),
            Color(red: 0.72, green: 0.90, blue: 0.78),
            Color(red: 0.78, green: 0.72, blue: 1.00),
            Color(red: 1.00, green: 0.85, blue: 0.44),
            Color(red: 0.60, green: 0.82, blue: 1.00),
            Color(red: 0.95, green: 0.65, blue: 0.85),
        ]
        return colors[Int(hash % UInt64(colors.count))]
    }

    /// 简单 FNV-1a，保证跨进程稳定（Swift hashValue 是 process-salted 的）。
    private static func stableHash(_ s: String) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325
        for b in s.utf8 {
            h ^= UInt64(b)
            h = h &* 0x100000001b3
        }
        return h
    }
}

extension HistoryItem {
    /// 是否是「收件箱」要展示的（已接收的文件 / 图片）。
    var isInboxFile: Bool {
        guard direction == .incoming else { return false }
        if case .file = kind { return true }
        return false
    }
}

extension Device {
    /// 雷达 / 头像用的人名缩写
    var displayInitials: String { EngineAdapters.initials(for: name) }
}
