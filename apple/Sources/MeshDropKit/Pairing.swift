import Foundation

/// 一个等待用户批准的入站连接。
///
/// 由被动方（accept 端）创建：收到对方 HELLO 后若 `fp` 不在 [TrustStore] 中，
/// 即生成一个 PairingRequest 投递给 UI。用户决定后调用
/// `ShareEngine.respondToPairing(_:decision:)`。
public struct PairingRequest: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let peer: Device
    public let receivedAt: Date

    public init(id: UUID = UUID(), peer: Device, receivedAt: Date = Date()) {
        self.id = id
        self.peer = peer
        self.receivedAt = receivedAt
    }
}

public enum PairingDecision: Sendable {
    /// 拒绝：立刻关闭连接，不写信任库。
    case reject
    /// 允许一次：进入业务消息，但不写信任库；下次仍需用户确认。
    case allowOnce
    /// 允许并记住：写入信任库，下次自动放行。
    case trust
}
