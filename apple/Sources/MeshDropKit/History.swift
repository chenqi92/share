import Foundation

/// 历史记录中一条数据（既包括我发出的也包括我收到的，统一在一个 timeline）。
public struct HistoryItem: Identifiable, Sendable, Equatable {
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
}

public enum TransferDirection: String, Sendable, Equatable {
    case outgoing   // 我发出去
    case incoming   // 别人发给我
}

public enum HistoryKind: Sendable, Equatable {
    case text(String)
    /// 文件：name 是显示名，size 是字节数，url 是本地落盘后的路径（发送侧 = 源文件；接收侧 = 保存路径）。
    case file(name: String, size: UInt64, url: URL?)
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

public enum TransferStatus: Sendable, Equatable {
    case pending                       // 创建但还没开始传
    case waitingApproval               // 等对方接受（出方）或等本地决定（入方）
    case transferring(bytesDone: UInt64, bytesTotal: UInt64)
    case completed
    case failed(String)
    case canceled

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
