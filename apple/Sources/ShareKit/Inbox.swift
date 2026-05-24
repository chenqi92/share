import Foundation

/// 已接收的一条消息。骨架阶段只有 `.text`，后续加 `.file`。
public struct InboxItem: Identifiable, Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case text(String)
        // case file(name: String, size: UInt64, url: URL)  // TODO
    }

    public let id: UUID
    public let peer: Device
    public let kind: Kind
    public let receivedAt: Date

    public init(
        id: UUID = UUID(),
        peer: Device,
        kind: Kind,
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.peer = peer
        self.kind = kind
        self.receivedAt = receivedAt
    }
}
