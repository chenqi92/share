import Foundation
import SwiftUI
import MeshDropKit

// MARK: - Engine 类型 → UI mock-shape 类型 的投影
//
// UI 阶段是直接用 MockDevice / MockHistory / MockPendingPairing / MockPendingOffer /
// MockTrustedDevice 这些视觉密集的结构体绘制的（带颜色、initials、角度等）。
// backend 接入轮不重做视觉，转而把 ShareEngine 的真实类型投影到这些 mock 视觉类型上，
// 让原 UI 代码改最少的引用即可。
//
// Mock 结构体本身保留给 SwiftUI Preview 用。

extension MockDevice {
    /// 把 Engine 的 Device 投影成 UI 用的 MockDevice。
    /// 显示用的 angle / dist / color / initials 由 id 哈希稳定派生。
    static func from(_ device: Device, online: Bool = true) -> MockDevice {
        let initials = makeInitials(device.name)
        let kind = mapKind(device.os)
        let osLabel = osLabel(device.os, model: device.model)
        let stableAngle = stableDouble(device.id, salt: "angle", in: 0..<360)
        let stableDist = stableDouble(device.id, salt: "dist", in: 0.3..<0.92)
        let color = stableColor(device.id)
        return MockDevice(
            id: device.id,
            name: device.name,
            who: device.name,
            kind: kind,
            dist: stableDist,
            angle: stableAngle,
            color: color,
            initials: initials,
            os: osLabel,
            rtt: stableRtt(device.id),
            online: online
        )
    }
}

extension MockHistory {
    /// 把 Engine 的 HistoryItem 投影成 UI 用的 MockHistory。
    static func from(_ item: HistoryItem) -> MockHistory {
        let dir: HistoryDir = (item.direction == .outgoing) ? .outgoing : .incoming
        let time = Self.timeFormatter.string(from: item.createdAt)
        let status: HistoryStatus
        switch item.status {
        case .completed: status = .done
        case .transferring: status = .transferring
        case .pending, .waitingApproval: status = .queued
        case .failed, .canceled: status = .failed
        }
        switch item.kind {
        case .text(let s):
            return MockHistory(
                id: item.id.uuidString,
                dir: dir,
                peer: item.peer.name,
                time: time,
                kind: .text,
                content: s,
                status: status
            )
        case .file(let name, let size, _):
            let ext = (name as NSString).pathExtension.lowercased()
            let sizeStr = byteFormatter.string(fromByteCount: Int64(size))
            let progress: Int? = {
                if case let .transferring(done, total) = item.status, total > 0 {
                    return Int(Double(done) / Double(total) * 100)
                }
                return nil
            }()
            return MockHistory(
                id: item.id.uuidString,
                dir: dir,
                peer: item.peer.name,
                time: time,
                kind: .file,
                name: name,
                size: sizeStr,
                ext: ext.isEmpty ? "bin" : ext,
                progress: progress,
                status: status
            )
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

extension MockPendingPairing {
    static func from(_ req: PairingRequest) -> MockPendingPairing {
        MockPendingPairing(
            id: req.id.uuidString,
            peer: req.peer.name,
            deviceName: req.peer.model ?? req.peer.name,
            fingerprint: req.peer.humanFingerprint,
            receivedAt: shortAgo(from: req.receivedAt)
        )
    }
}

extension MockPendingOffer {
    static func from(_ offer: PendingFileOffer) -> MockPendingOffer {
        MockPendingOffer(
            id: offer.id.uuidString,
            peer: offer.peer.name,
            deviceName: offer.peer.model ?? offer.peer.name,
            fileName: offer.fileName,
            fileSize: offer.formattedSize,
            note: "",
            receivedAt: shortAgo(from: offer.receivedAt)
        )
    }
}

extension MockTrustedDevice {
    static func from(_ record: TrustRecord, online: Bool = false, kind: DeviceKind = .mac) -> MockTrustedDevice {
        MockTrustedDevice(
            id: record.fingerprint,
            name: record.name,
            who: record.name,
            kind: kind,
            fingerprint: humanize(record.fingerprint),
            pairedAt: dateFormatter.string(from: record.firstSeen),
            lastSeen: shortAgo(from: record.lastSeen),
            online: online
        )
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - 辅助

private let byteFormatter: ByteCountFormatter = {
    let f = ByteCountFormatter()
    f.allowedUnits = [.useKB, .useMB, .useGB]
    f.countStyle = .file
    return f
}()

private func makeInitials(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "?" }
    let parts = trimmed.split(separator: " ")
    if parts.count >= 2 {
        let a = parts[0].first.map { String($0) } ?? ""
        let b = parts[1].first.map { String($0) } ?? ""
        return (a + b).uppercased()
    }
    // 中文 / 单 token：取头两字
    return String(trimmed.prefix(2))
}

private func mapKind(_ os: DeviceOS) -> DeviceKind {
    switch os {
    case .ios: return .ios
    case .android: return .android
    case .macos: return .mac
    case .windows: return .win
    case .linux: return .mac
    }
}

private func osLabel(_ os: DeviceOS, model: String?) -> String {
    if let model, !model.isEmpty { return model }
    switch os {
    case .ios: return "iOS"
    case .android: return "Android"
    case .macos: return "macOS"
    case .windows: return "Windows"
    case .linux: return "Linux"
    }
}

private func stableDouble(_ id: String, salt: String, in range: Range<Double>) -> Double {
    let seed = abs((id + "|" + salt).hashValue)
    let span = range.upperBound - range.lowerBound
    return range.lowerBound + Double(seed % 1000) / 1000.0 * span
}

private let kPalette: [UInt32] = [
    0xFFB4A1, 0xB7E5C8, 0xC7B8FF, 0xFFD970, 0x9AD0FF,
    0xFFC4DC, 0xCFE8B0, 0xFFD1A6, 0xA9E0E0
]

private func stableColor(_ id: String) -> Color {
    let i = abs(id.hashValue) % kPalette.count
    return Color(hex: kPalette[i])
}

private func stableRtt(_ id: String) -> Int {
    Int(stableDouble(id, salt: "rtt", in: 8..<48))
}

private func shortAgo(from date: Date) -> String {
    let s = max(0, Int(Date().timeIntervalSince(date)))
    if s < 60 { return "\(s)s 前" }
    let m = s / 60
    if m < 60 { return "\(m) 分钟前" }
    let h = m / 60
    if h < 24 { return "\(h) 小时前" }
    return "\(h / 24) 天前"
}

private func humanize(_ fp: String) -> String {
    let upper = fp.uppercased()
    var out: [String] = []
    var idx = upper.startIndex
    while idx < upper.endIndex {
        let end = upper.index(idx, offsetBy: 4, limitedBy: upper.endIndex) ?? upper.endIndex
        out.append(String(upper[idx..<end]))
        idx = end
    }
    return out.joined(separator: " · ")
}
