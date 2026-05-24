import SwiftUI

/// 把 [BridgeDevice]（来自 companion 桥接的协议层数据）适配到现有 UI 渲染所需的字段。
/// Preview 走 mock/MockData.swift；运行时走 proxy.devices 经此适配。
struct WatchDeviceVM: Identifiable, Hashable {
    let id: String
    let name: String
    let who: String
    let kind: String
    let os: String
    let rtt: Int
    let initials: String
    let color: Color

    init(bridge d: BridgeDevice) {
        self.id = d.id
        self.name = d.model.map { "\(d.displayName) · \($0)" } ?? d.displayName
        self.who = d.displayName
        self.kind = d.kind
        self.os = Self.osLabel(forKind: d.kind, model: d.model)
        self.rtt = d.rttMs ?? 0
        self.initials = Self.initials(from: d.displayName)
        self.color = Self.color(seed: d.id)
    }

    /// 从 MockDevice 透传（Preview / mock-only 通路）。
    init(mock m: MockDevice) {
        self.id = m.id
        self.name = m.name
        self.who = m.who
        self.kind = m.kind
        self.os = m.os
        self.rtt = m.rtt
        self.initials = m.initials
        self.color = m.color
    }

    private static func osLabel(forKind kind: String, model: String?) -> String {
        if let model, !model.isEmpty { return model }
        switch kind {
        case "mac":      return "macOS"
        case "ios":      return "iOS"
        case "ipad":     return "iPadOS"
        case "android":  return "Android"
        case "win":      return "Win"
        case "linux":    return "Linux"
        case "tv":       return "tvOS"
        case "vision":   return "visionOS"
        case "watch":    return "watchOS"
        case "wear":     return "Wear OS"
        case "web":      return "Web"
        default:         return kind.uppercased()
        }
    }

    private static func initials(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "?" }
        // 中文：取第一个字
        if trimmed.unicodeScalars.first.map({ $0.value > 0x3400 }) ?? false {
            return String(trimmed.prefix(1))
        }
        // 英文：取每个 token 首字母，最多两位
        let tokens = trimmed.split(separator: " ").prefix(2)
        return tokens.map { String($0.prefix(1)).uppercased() }.joined()
    }

    /// 基于 id 的稳定 hash → 暖色板。
    private static func color(seed: String) -> Color {
        let palette: [Color] = [
            Color(red: 1.00, green: 0.70, blue: 0.63),
            Color(red: 0.72, green: 0.90, blue: 0.78),
            Color(red: 0.78, green: 0.72, blue: 1.00),
            Color(red: 1.00, green: 0.85, blue: 0.44),
            Color(red: 0.60, green: 0.82, blue: 1.00),
        ]
        let h = seed.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) & 0x7fffffff }
        return palette[h % palette.count]
    }
}

/// 把 [BridgeOffer] 适配到 ReceivePage 现有的 MockFileOffer 字段。
struct WatchOfferVM {
    let id: String
    let peerId: String
    let peer: String
    let deviceName: String
    let fileName: String
    let fileSize: String
    let ext: String
    let note: String
    let receivedAt: String

    init(bridge o: BridgeOffer, peerKind: String? = nil) {
        self.id = o.id
        self.peerId = o.peerId
        self.peer = o.peerName
        let kindLabel = WatchDeviceVM.init(bridge: BridgeDevice(
            id: o.peerId, displayName: o.peerName,
            kind: peerKind ?? "ios", model: nil, ip: nil, rttMs: nil,
            online: true, trusted: true, busy: false
        )).os
        self.deviceName = "\(o.peerName) · \(kindLabel)"
        let first = o.files.first
        self.fileName = first?.name ?? (o.kind == "text" ? "（文本）" : "—")
        self.fileSize = Self.formatBytes(first?.sizeBytes ?? 0)
        self.ext = (first?.name as NSString?)?.pathExtension ?? ""
        self.note = o.noteText ?? ""
        self.receivedAt = "刚刚"
    }

    init(mock m: MockFileOffer) {
        self.id = "mock-offer"
        self.peerId = "mock-peer"
        self.peer = m.peer
        self.deviceName = m.deviceName
        self.fileName = m.fileName
        self.fileSize = m.fileSize
        self.ext = m.ext
        self.note = m.note
        self.receivedAt = m.receivedAt
    }

    private static func formatBytes(_ n: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var v = Double(n)
        var idx = 0
        while v >= 1024 && idx < units.count - 1 { v /= 1024; idx += 1 }
        return idx == 0 ? "\(Int(v)) \(units[idx])" : String(format: "%.1f %@", v, units[idx])
    }
}

/// 把 [BridgeTransferProgress] 适配到 TransferPage 现有的 MockTransfer 字段。
struct WatchTransferVM {
    let id: String
    let name: String
    let size: String
    let ext: String
    let direction: MockTransfer.Direction
    let peer: String
    let progress: Int
    let speed: String?
    let eta: String?
    let state: MockTransfer.State

    init(bridge p: BridgeTransferProgress,
         offerName: String = "传输中",
         peerName: String = "",
         direction: MockTransfer.Direction = .outgoing) {
        self.id = p.id
        self.name = offerName
        self.size = Self.formatBytes(p.totalBytes)
        self.ext = (offerName as NSString).pathExtension
        self.direction = direction
        self.peer = peerName
        self.progress = p.progressPercent
        self.speed = p.speedBps.map { Self.formatBytes($0) + "/s" }
        self.eta = Self.formatEta(progress: p.progressPercent, speedBps: p.speedBps, total: p.totalBytes, sent: p.bytesSent)
        self.state = direction == .outgoing ? .sending : .receiving
    }

    init(mock m: MockTransfer) {
        self.id = m.id
        self.name = m.name
        self.size = m.size
        self.ext = m.ext
        self.direction = m.direction
        self.peer = m.peer
        self.progress = m.progress
        self.speed = m.speed
        self.eta = m.eta
        self.state = m.state
    }

    private static func formatBytes(_ n: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var v = Double(n)
        var idx = 0
        while v >= 1024 && idx < units.count - 1 { v /= 1024; idx += 1 }
        return idx == 0 ? "\(Int(v)) \(units[idx])" : String(format: "%.1f %@", v, units[idx])
    }

    private static func formatEta(progress: Int, speedBps: Int64?, total: Int64, sent: Int64) -> String? {
        guard let speed = speedBps, speed > 0 else { return nil }
        let remaining = max(total - sent, 0)
        let seconds = Int(Double(remaining) / Double(speed))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
