import SwiftUI
import MeshDropKit

/// 把真实 `Device` 映射到 UI 用的 `MockDevice` —— 颜色 / 方位角 / 半径都按 device.id
/// 稳定哈希得出，保证同一台设备每次出现在同一位置。
enum LivePeerMapper {

    private static let palette: [Color] = [
        Color(red: 1.00, green: 0.71, blue: 0.63),  // 暖橙
        Color(red: 0.72, green: 0.90, blue: 0.79),  // 薄荷
        Color(red: 0.78, green: 0.72, blue: 1.00),  // 雾紫
        Color(red: 1.00, green: 0.85, blue: 0.44),  // 暖黄
        Color(red: 0.60, green: 0.82, blue: 1.00),  // 海蓝
        Color(red: 0.95, green: 0.74, blue: 0.86),  // 浅粉
        Color(red: 0.66, green: 0.88, blue: 0.96),  // 冰蓝
    ]

    /// 把一组真实设备转换为 UI 用的 MockDevice 列表，按 id 稳定排序。
    static func map(_ devices: [Device]) -> [MockDevice] {
        let sorted = devices.sorted { $0.id < $1.id }
        return sorted.enumerated().map { (idx, dev) in
            mockDevice(from: dev, index: idx, total: max(sorted.count, 1))
        }
    }

    static func mockDevice(from device: Device, index: Int, total: Int) -> MockDevice {
        let hash = stableHash(device.id)
        let kind = uiKind(for: device.os, model: device.model)
        let colorIdx = Int(hash % UInt64(palette.count))
        // 在圆周均匀打散，再加一点 hash 抖动避免重叠
        let baseSlice = Double(index) * (360.0 / Double(total))
        let jitter = Double(hash % 30) - 15.0
        let angle = (baseSlice + jitter + 30.0).truncatingRemainder(dividingBy: 360.0)
        let dist = 0.40 + Double((hash / 7) % 55) / 100.0       // 0.40 ~ 0.95
        let approxMeters = 1.0 + Double((hash / 13) % 60) / 10.0 // 1.0 ~ 7.0
        return MockDevice(
            id: device.id,
            name: device.model ?? device.name,
            who: device.name.isEmpty ? "未命名" : device.name,
            kind: kind,
            dist: dist,
            angle: angle,
            color: palette[colorIdx],
            initials: initials(from: device.name),
            os: device.os.displayLabel,
            rtt: 0,
            approxMeters: approxMeters
        )
    }

    private static func uiKind(for os: DeviceOS, model: String?) -> MeshDropKind {
        switch os {
        case .macos:   return .mac
        case .windows: return .win
        case .android: return .android
        case .linux:   return .win
        case .ios:
            if let m = model?.lowercased(), m.contains("ipad") { return .ipad }
            return .ios
        }
    }

    private static func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace || $0 == "·" || $0 == "-" || $0 == "_" })
        if words.count >= 2 {
            let a = words[0].first.map { String($0) } ?? ""
            let b = words[1].first.map { String($0) } ?? ""
            return (a + b).uppercased()
        }
        return String(trimmed.prefix(2)).uppercased()
    }

    /// 用 SipHash-like 折叠：把 id 的字节累加成一个稳定的 64-bit 数。
    private static func stableHash(_ s: String) -> UInt64 {
        var acc: UInt64 = 1469598103934665603  // FNV-1a offset
        for byte in s.utf8 {
            acc ^= UInt64(byte)
            acc &*= 1099511628211
        }
        return acc
    }
}

extension DeviceOS {
    var displayLabel: String {
        switch self {
        case .ios:     return "iOS"
        case .macos:   return "macOS"
        case .android: return "Android"
        case .windows: return "Windows"
        case .linux:   return "Linux"
        }
    }
}

/// 把 `engine.history` 中"进行中"那部分映射到 TransfersPage 的飞行任务模型。
enum LiveTransferMapper {

    static func inFlight(from history: [HistoryItem], selfName: String) -> [MockData.InFlightTransfer] {
        history.compactMap { item -> MockData.InFlightTransfer? in
            guard case .transferring(let done, let total) = item.status, total > 0 else { return nil }
            let name: String
            let ext: String
            let size: String
            switch item.kind {
            case .text(let body):
                name = body.count > 40 ? String(body.prefix(40)) + "…" : body
                ext = "txt"
                size = "\(body.count) 字"
            case .file(let fileName, let bytes, _):
                name = fileName
                ext = (fileName as NSString).pathExtension
                size = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
            }
            let progress = Double(done) / Double(total)
            let direction: MockData.InFlightTransfer.Direction =
                item.direction == .outgoing ? .outgoing : .incoming
            let fromId = direction == .outgoing ? "me"        : item.peer.id
            let toId   = direction == .outgoing ? item.peer.id : "me"
            return MockData.InFlightTransfer(
                id: item.id.uuidString,
                name: name,
                size: size,
                ext: ext.isEmpty ? "bin" : ext,
                fromId: fromId,
                toId: toId,
                progress: progress,
                speed: "…",
                eta: "…",
                direction: direction
            )
        }
    }
}
