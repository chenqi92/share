import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "drop.mesh.MeshDropKit", category: "Connection")

/// 包装一条 NWConnection，提供按帧 (`Frame`) 读写的串行化接口。
///
/// - 由 actor 保证串行；上层不需要自己加锁。
/// - 读循环在 NWConnection 进入 `.ready` 后启动，按 [transport.md](../../../protocol/transport.md)
///   的 framing 规范解出 (type, body) 投给 `onMessage`。
/// - 任一侧关闭、出错都会触发 `onClose`，触发后不再有任何回调。
public actor Connection {
    private let nw: NWConnection
    private var readBuffer = Data()
    private var isClosed = false

    private var onMessage: ((UInt8, Data) async -> Void)?
    private var onClose: ((Error?) async -> Void)?
    private var onReady: (() async -> Void)?

    /// 远端 endpoint 字符串，主要用于日志。
    public nonisolated var endpointDescription: String {
        String(describing: nw.endpoint)
    }

    public init(nwConnection: NWConnection) {
        self.nw = nwConnection
    }

    /// 用目标设备建一条出方连接。
    public init(connectingTo device: Device) {
        let host = NWEndpoint.Host("\(device.id).local")
        let port = NWEndpoint.Port(rawValue: device.port)!
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        self.nw = NWConnection(host: host, port: port, using: params)
    }

    public func start(
        onReady: @escaping () async -> Void,
        onMessage: @escaping (UInt8, Data) async -> Void,
        onClose: @escaping (Error?) async -> Void
    ) {
        self.onReady = onReady
        self.onMessage = onMessage
        self.onClose = onClose

        nw.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            Task { await self.handleNWState(state) }
        }
        nw.start(queue: .global(qos: .userInitiated))
    }

    public func send(type: UInt8, body: Data) async throws {
        if isClosed { throw ConnectionError.alreadyClosed }
        let frame = Frame.encode(type: type, body: body)
        try await sendRaw(frame)
    }

    public func close() {
        guard !isClosed else { return }
        isClosed = true
        nw.cancel()
    }

    // MARK: - 内部

    private func handleNWState(_ state: NWConnection.State) async {
        switch state {
        case .ready:
            log.debug("connection ready: \(self.endpointDescription)")
            await onReady?()
            await readLoop()
        case .failed(let err):
            log.info("connection failed (\(self.endpointDescription)): \(err.localizedDescription)")
            await closeInternal(error: err)
        case .cancelled:
            await closeInternal(error: nil)
        default:
            break
        }
    }

    private func readLoop() async {
        while !isClosed {
            do {
                guard let chunk = try await receiveChunk() else {
                    await closeInternal(error: nil)
                    return
                }
                readBuffer.append(chunk)
                try await drainFrames()
            } catch {
                await closeInternal(error: error)
                return
            }
        }
    }

    private func drainFrames() async throws {
        while true {
            let decoded: (type: UInt8, body: Data, consumed: Int)?
            do {
                decoded = try Frame.decode(readBuffer)
            } catch {
                throw error
            }
            guard let f = decoded else { return }
            readBuffer.removeFirst(f.consumed)
            await onMessage?(f.type, f.body)
        }
    }

    private func receiveChunk() async throws -> Data? {
        try await withCheckedThrowingContinuation { cont in
            nw.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
                if let error {
                    cont.resume(throwing: error)
                } else if isComplete && (data?.isEmpty ?? true) {
                    cont.resume(returning: nil)
                } else {
                    cont.resume(returning: data)
                }
            }
        }
    }

    private func sendRaw(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            nw.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    private func closeInternal(error: Error?) async {
        if isClosed { return }
        isClosed = true
        nw.cancel()
        await onClose?(error)
        onMessage = nil
        onClose = nil
        onReady = nil
    }
}

public enum ConnectionError: Error {
    case alreadyClosed
}
