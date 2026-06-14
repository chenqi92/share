import Foundation

/// 历史记录中一条数据（既包括我发出的也包括我收到的，统一在一个 timeline）。
public struct HistoryItem: Identifiable, Sendable, Equatable, Codable {
    public let id: UUID
    public let peer: Device
    public let direction: TransferDirection
    public var kind: HistoryKind
    public var status: TransferStatus
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        peer: Device,
        direction: TransferDirection,
        kind: HistoryKind,
        status: TransferStatus,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.peer = peer
        self.direction = direction
        self.kind = kind
        self.status = status
        self.createdAt = createdAt
    }

    // MARK: - Codable（落盘用）
    //
    // 历史是给「人回看」的，对端可能早已离线，因此持久化时**只拍对端的快照** {fp, name, os}，
    // 不存 Device 的运行时字段（id / port / protocolVersion —— 这些重启 / 重新发现后都会变，
    // 存了也没意义还会误导）。解码时用快照重建一个 Device 给 UI 用，缺失的运行时字段填占位值：
    // - id     用 fp 兜底（仅历史展示，不会拿去建连接）
    // - model  历史不单独存 model，留空
    // - port   填 0（历史项不参与发现 / 连接）
    private enum CodingKeys: String, CodingKey {
        case id, peerFingerprint, peerName, peerOS, direction, kind, status, createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(peer.fingerprint, forKey: .peerFingerprint)
        try c.encode(peer.name, forKey: .peerName)
        try c.encode(peer.os, forKey: .peerOS)
        try c.encode(direction, forKey: .direction)
        try c.encode(kind, forKey: .kind)
        try c.encode(status, forKey: .status)
        try c.encode(createdAt, forKey: .createdAt)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        let fp = try c.decode(String.self, forKey: .peerFingerprint)
        let name = try c.decode(String.self, forKey: .peerName)
        let os = try c.decode(DeviceOS.self, forKey: .peerOS)
        self.peer = Device(id: fp, name: name, os: os, fingerprint: fp, port: 0)
        self.direction = try c.decode(TransferDirection.self, forKey: .direction)
        self.kind = try c.decode(HistoryKind.self, forKey: .kind)
        self.status = try c.decode(TransferStatus.self, forKey: .status)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}

public enum TransferDirection: String, Sendable, Equatable, Codable {
    case outgoing   // 我发出去
    case incoming   // 别人发给我
}

public enum HistoryKind: Sendable, Equatable, Codable {
    case text(String)
    /// 文件：name 是显示名，size 是字节数，url 是本地落盘后的路径（发送侧 = 源文件；接收侧 = 保存路径）。
    case file(name: String, size: UInt64, url: URL?)

    // 手写 Codable：用 "type" 标签区分 case；URL 以 file path 的形式存（缺省 nil）。
    // url 落盘后回看可能已失效（源文件被移走 / sandbox 路径变化），但保留路径仍便于「重发 / 打开」尝试。
    private enum CodingKeys: String, CodingKey { case type, text, name, size, url }
    private enum Kind: String, Codable { case text, file }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode(Kind.text, forKey: .type)
            try c.encode(s, forKey: .text)
        case .file(let name, let size, let url):
            try c.encode(Kind.file, forKey: .type)
            try c.encode(name, forKey: .name)
            try c.encode(size, forKey: .size)
            try c.encodeIfPresent(url?.path, forKey: .url)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .text:
            self = .text(try c.decode(String.self, forKey: .text))
        case .file:
            let name = try c.decode(String.self, forKey: .name)
            let size = try c.decode(UInt64.self, forKey: .size)
            let path = try c.decodeIfPresent(String.self, forKey: .url)
            self = .file(name: name, size: size, url: path.map { URL(fileURLWithPath: $0) })
        }
    }
}

/// 剪贴板收件箱条目 —— 对端显式推来的剪贴板内容。
public struct ClipboardEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let peerName: String
    public let content: String
    public let kind: String        // text | link | code
    public let receivedAt: Date

    public init(id: UUID = UUID(), peerName: String, content: String, kind: String, receivedAt: Date = Date()) {
        self.id = id
        self.peerName = peerName
        self.content = content
        self.kind = kind
        self.receivedAt = receivedAt
    }
}

/// 会话级吞吐时间序列：每秒一个桶，上行 / 下行 bytes/sec。最旧在前、最新在后，
/// 长度上限 32（不足时短）。供传输页速度柱状图绘制真实数据用。
public struct SessionThroughput: Sendable, Equatable {
    public var up: [Double]
    public var down: [Double]
    public init(up: [Double] = [], down: [Double] = []) {
        self.up = up
        self.down = down
    }
}

/// 进行中传输的实时指标。仅在 .transferring 阶段有意义，进入 terminal 时清除。
public struct TransferMetrics: Sendable, Equatable {
    /// 平滑后的字节/秒。0 表示未收到足够样本。
    public let bytesPerSec: Double
    /// 剩余时间（秒）；速率为 0 或 total<=done 时为 nil。
    public let etaSeconds: Double?

    public init(bytesPerSec: Double, etaSeconds: Double?) {
        self.bytesPerSec = bytesPerSec
        self.etaSeconds = etaSeconds
    }
}

public enum TransferStatus: Sendable, Equatable, Codable {
    case pending                       // 创建但还没开始传
    case waitingApproval               // 等对方接受（出方）或等本地决定（入方）
    case transferring(bytesDone: UInt64, bytesTotal: UInt64)
    case completed
    case failed(String)
    case canceled

    // 手写 Codable：用 "state" 标签区分 case，带 payload 的 case 额外存字段。
    private enum CodingKeys: String, CodingKey { case state, bytesDone, bytesTotal, reason }
    private enum State: String, Codable { case pending, waitingApproval, transferring, completed, failed, canceled }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pending:          try c.encode(State.pending, forKey: .state)
        case .waitingApproval:  try c.encode(State.waitingApproval, forKey: .state)
        case .transferring(let done, let total):
            try c.encode(State.transferring, forKey: .state)
            try c.encode(done, forKey: .bytesDone)
            try c.encode(total, forKey: .bytesTotal)
        case .completed:        try c.encode(State.completed, forKey: .state)
        case .failed(let r):
            try c.encode(State.failed, forKey: .state)
            try c.encode(r, forKey: .reason)
        case .canceled:         try c.encode(State.canceled, forKey: .state)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(State.self, forKey: .state) {
        case .pending:          self = .pending
        case .waitingApproval:  self = .waitingApproval
        case .transferring:
            let done = try c.decode(UInt64.self, forKey: .bytesDone)
            let total = try c.decode(UInt64.self, forKey: .bytesTotal)
            self = .transferring(bytesDone: done, bytesTotal: total)
        case .completed:        self = .completed
        case .failed:           self = .failed(try c.decode(String.self, forKey: .reason))
        case .canceled:         self = .canceled
        }
    }

    public var progressFraction: Double {
        if case let .transferring(done, total) = self, total > 0 {
            return min(1.0, Double(done) / Double(total))
        }
        if case .completed = self { return 1.0 }
        return 0.0
    }

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .canceled: return true
        default: return false
        }
    }
}
