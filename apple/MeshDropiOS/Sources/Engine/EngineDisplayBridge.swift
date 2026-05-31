import Foundation
import MeshDropKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Device → MockDevice 适配

extension Device {
    /// 把真实 Device 投射成 UI 用的 MockDevice。dist / angle / 颜色 / initials 来自 id 的稳定哈希，
    /// 保证同一台设备每次出现在雷达上的位置都一致。
    public var displayMock: MockDevice { displayMock(isOnline: true) }

    public func displayMock(isOnline: Bool) -> MockDevice {
        let bucket = Self.bucket(id)
        return MockDevice(
            id: id,
            name: model ?? name,
            who: name,
            kind: Self.mapKind(os),
            dist: 0.32 + Double(bucket % 13) / 13.0 * 0.55,
            angle: Double((bucket / 13) % 360),
            colorHex: Self.palette[bucket % Self.palette.count],
            initials: Self.initials(name),
            os: Self.osLabel(os),
            rtt: 12 + bucket % 40,
            isOnline: isOnline
        )
    }

    private static let palette: [UInt32] = [
        0xFFB4A1, 0xB7E5C8, 0xC7B8FF, 0xFFD970, 0x9AD0FF,
        0xFFC7E0, 0xA8E1D4, 0xE8C9FF, 0xFFE3A1, 0xBED7FF
    ]

    private static func bucket(_ id: String) -> Int {
        var h: UInt64 = 1469598103934665603 // FNV-1a 64
        for b in id.utf8 {
            h ^= UInt64(b)
            h &*= 1099511628211
        }
        return Int(h & 0x7FFFFFFF)
    }

    private static func mapKind(_ os: DeviceOS) -> MockDeviceKind {
        switch os {
        case .ios:     return .ios
        case .macos:   return .mac
        case .android: return .android
        case .windows: return .win
        case .linux:   return .linux
        }
    }

    private static func osLabel(_ os: DeviceOS) -> String {
        switch os {
        case .ios:     return "iOS"
        case .macos:   return "macOS"
        case .android: return "Android"
        case .windows: return "Win"
        case .linux:   return "Linux"
        }
    }

    static func initials(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "?" }
        let parts = trimmed.split(whereSeparator: { $0 == " " || $0 == "·" || $0 == "-" })
        if let first = parts.first, let firstChar = first.first {
            if parts.count >= 2, let secondChar = parts[1].first {
                return String([firstChar, secondChar]).uppercased()
            }
            // 中文姓名取首字
            if firstChar.unicodeScalars.first.map({ $0.value > 0x4E00 }) == true {
                return String(firstChar)
            }
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

// MARK: - HistoryItem → MockHistoryItem / MockTransfer / MockMessage

extension HistoryItem {
    public var displayHistory: MockHistoryItem {
        let dir: MockDir = (direction == .outgoing) ? .outgoing : .incoming
        let status: MockStatus
        var progress: Int? = nil
        switch self.status {
        case .completed:                                  status = .done
        case .pending, .waitingApproval:                  status = .queued
        case .transferring(let done, let total):
            status = .transferring
            progress = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
        case .failed:                                     status = .failed
        case .canceled:                                   status = .failed
        }
        switch kind {
        case .text(let content):
            return MockHistoryItem(
                id: id.uuidString,
                dir: dir,
                peer: peer.name,
                time: Self.timeFormatter.string(from: createdAt),
                kind: .text,
                count: nil, name: nil, size: nil, ext: nil,
                content: content,
                progress: progress,
                status: status
            )
        case .file(let name, let size, let url):
            let ext = (name as NSString).pathExtension
            return MockHistoryItem(
                id: id.uuidString,
                dir: dir,
                peer: peer.name,
                time: Self.timeFormatter.string(from: createdAt),
                kind: Self.isImageFile(name: name, url: url) ? .image : .file,
                count: Self.isImageFile(name: name, url: url) ? 1 : nil,
                name: name,
                size: Self.byteFormatter.string(fromByteCount: Int64(size)),
                ext: ext.isEmpty ? "?" : ext,
                fileURL: url,
                content: nil,
                progress: progress,
                status: status
            )
        }
    }

    public func displayTransfer(metrics: TransferMetrics? = nil) -> MockTransfer? {
        guard case .file(let name, let size, _) = kind else { return nil }
        let dir: MockDir = (direction == .outgoing) ? .outgoing : .incoming
        let state: MockStatus
        var progress = 0
        var speed: String? = nil
        var eta: String? = nil
        var failReason: String? = nil
        switch status {
        case .completed:
            state = .done; progress = 100
        case .pending, .waitingApproval:
            state = .queued; progress = 0
        case .transferring(let done, let total):
            state = .transferring
            progress = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
            if let m = metrics, m.bytesPerSec > 1 {
                speed = "\(Self.byteFormatter.string(fromByteCount: Int64(m.bytesPerSec)))/s"
            }
            if let secs = metrics?.etaSeconds {
                eta = Self.formatEta(secs)
            }
        case .failed(let reason):
            state = .failed; failReason = reason
        case .canceled:
            state = .failed; failReason = "已取消"
        }
        let ext = (name as NSString).pathExtension
        return MockTransfer(
            id: id.uuidString,
            name: name,
            size: Self.byteFormatter.string(fromByteCount: Int64(size)),
            ext: ext.isEmpty ? "?" : ext,
            from: dir == .outgoing ? "我" : peer.name,
            to: dir == .outgoing ? peer.name : "我",
            progress: progress,
            state: state,
            direction: dir,
            speed: speed,
            eta: eta,
            failReason: failReason
        )
    }

    /// 兼容老调用点 (`.displayTransfer` 属性访问)，等于 displayTransfer(metrics: nil)。
    public var displayTransfer: MockTransfer? { displayTransfer(metrics: nil) }

    public var displayMessage: MockMessage {
        let dir: MockDir = (direction == .outgoing) ? .outgoing : .incoming
        let delivered = status == .completed
        let time = Self.timeFormatter.string(from: createdAt)
        switch kind {
        case .text(let content):
            return MockMessage(
                id: id.uuidString, dir: dir, kind: .text,
                text: content, time: time,
                fileName: nil, fileSize: nil, fileExt: nil,
                imageCount: nil, delivered: delivered
            )
        case .file(let name, let size, let url):
            let ext = (name as NSString).pathExtension
            return MockMessage(
                id: id.uuidString,
                dir: dir,
                kind: Self.isImageFile(name: name, url: url) ? .image : .file,
                text: nil, time: time,
                fileName: name,
                fileSize: Self.byteFormatter.string(fromByteCount: Int64(size)),
                fileExt: ext.isEmpty ? "?" : ext,
                fileURL: url,
                imageCount: Self.isImageFile(name: name, url: url) ? 1 : nil,
                delivered: delivered
            )
        }
    }

    static func isImageFile(name: String, url: URL?) -> Bool {
        if let url {
            let values = try? url.resourceValues(forKeys: [.contentTypeKey])
            if values?.contentType?.conforms(to: .image) == true { return true }
        }
        let ext = (name as NSString).pathExtension
        guard !ext.isEmpty else { return false }
        return UTType(filenameExtension: ext)?.conforms(to: .image) == true
    }

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f
    }()

    /// 把剩余秒数格式化成 "mm:ss" 或 ">1h" / "<1s"。
    static func formatEta(_ secs: Double) -> String {
        if !secs.isFinite || secs < 0 { return "—" }
        if secs < 1 { return "<1s" }
        if secs >= 3600 { return ">1h" }
        let s = Int(secs.rounded())
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Pairing / Offer / Trust 适配

extension PairingRequest {
    public var displayMock: MockPendingPairing {
        MockPendingPairing(
            id: id.uuidString,
            peer: peer.name,
            deviceName: peer.model ?? peer.name,
            fingerprint: peer.humanFingerprint,
            receivedAt: Self.ago(receivedAt)
        )
    }

    static func ago(_ date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        if secs < 60 { return "\(max(secs, 1))s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        return "\(secs / 3600)h ago"
    }
}

extension PendingFileOffer {
    public var displayMock: MockPendingOffer {
        let isImage = Self.isImage(fileName: fileName, mime: mime)
        return MockPendingOffer(
            id: id.uuidString,
            peer: peer.name,
            deviceName: peer.model ?? peer.name,
            fileName: fileName,
            fileSize: formattedSize,
            isImage: isImage,
            previewBase64: previewBase64,
            note: nil,
            receivedAt: PairingRequest.ago(receivedAt)
        )
    }

    private static func isImage(fileName: String, mime: String?) -> Bool {
        if mime?.hasPrefix("image/") == true { return true }
        let ext = (fileName as NSString).pathExtension
        guard !ext.isEmpty else { return false }
        return UTType(filenameExtension: ext)?.conforms(to: .image) == true
    }
}

extension TrustRecord {
    public var displayMock: MockTrustedPeer {
        MockTrustedPeer(
            id: fingerprint,
            name: name,
            device: name,
            fingerprint: Self.humanFingerprint(fingerprint),
            firstSeen: Self.dayFormatter.string(from: firstSeen),
            lastSeen: PairingRequest.ago(lastSeen)
        )
    }

    static func humanFingerprint(_ fp: String) -> String {
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

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Identity / self 设备

extension Identity {
    public func displaySelf(name: String, ip: String) -> MockMe {
        MockMe(
            name: name,
            fingerprint: TrustRecord.humanFingerprint(fingerprint),
            ip: ip,
            os: Self.osLabel,
            visibility: "可见"
        )
    }

    private static var osLabel: String {
        #if os(iOS)
        return "iOS 26"
        #else
        return "macOS"
        #endif
    }
}

// MARK: - ShareEngine 便利封装

extension ShareEngine {
    /// 当前 LAN 设备的 UI display 列表（按 id 稳定排序，避免雷达 / 列表跳动）。
    public var displayDevices: [MockDevice] {
        devices.map { $0.displayMock }.sorted { $0.id < $1.id }
    }

    /// 用 mock id（= device.id 或合成 id）找回真实 Device。
    public func realDevice(for mockId: String) -> Device? {
        devices.first(where: { $0.id == mockId })
    }

    /// 当前本机展示信息。`ip` 取本机首个 IPv4 局域网地址。
    public var displaySelf: MockMe {
        identity.displaySelf(name: displayName, ip: Self.primaryLANAddress() ?? "—")
    }

    /// 寻找本机第一个非环回 IPv4 地址，用于 UI "scanning · 192.168.x.x/24" 显示。
    nonisolated static func primaryLANAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let flags = Int32(cur.pointee.ifa_flags)
            let family = cur.pointee.ifa_addr.pointee.sa_family
            if family == UInt8(AF_INET),
               (flags & (IFF_UP | IFF_RUNNING)) != 0,
               (flags & IFF_LOOPBACK) == 0,
               let name = cur.pointee.ifa_name.flatMap({ String(cString: $0) }),
               // en0 = Wi-Fi, en1 = Wi-Fi alt, en2... = Ethernet/bridge
               name.hasPrefix("en") {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let saLen = socklen_t(cur.pointee.ifa_addr.pointee.sa_len)
                if getnameinfo(cur.pointee.ifa_addr, saLen,
                               &host, socklen_t(host.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    return String(cString: host)
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return nil
    }
}
