import Foundation

/// 一个等待用户决定的入站文件请求。由 ShareEngine 在收到 FILE_OFFER 时投递。
public struct PendingFileOffer: Identifiable, Sendable, Equatable {
    public let id: UUID                      // = transfer_id
    public let peer: Device
    public let fileName: String
    public let fileSize: UInt64
    public let sha256: String
    public let receivedAt: Date

    public init(
        id: UUID,
        peer: Device,
        fileName: String,
        fileSize: UInt64,
        sha256: String,
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.peer = peer
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256 = sha256
        self.receivedAt = receivedAt
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}
