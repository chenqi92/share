import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "Connection")

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
    private var becameReady = false

    /// 建连 + 进入 ready 的整体超时。service endpoint 解析不到对端 / 对端不可达时
    /// NWConnection 会停在 `.waiting`（不会自己 `.failed`），没有超时就会永远挂着，
    /// 上层 UI 表现为「无限加载」。超过此时限仍未 ready 即按超时失败。
    private static let establishTimeout: TimeInterval = 12

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
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let endpoint = NWEndpoint.service(
            name: device.id,
            type: TXTRecord.serviceType,
            domain: "local",
            interface: nil
        )
        self.nw = NWConnection(to: endpoint, using: params)
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

        // 建连超时兜底：N 秒内没进入 ready 就按超时失败，避免停在 .waiting/.preparing 无限挂起。
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.establishTimeout * 1_000_000_000))
            await self?.failIfNotReady()
        }
    }

    private func failIfNotReady() async {
        guard !becameReady, !isClosed else { return }
        log.info("connection establish timeout: \(self.endpointDescription)")
        await closeInternal(error: ConnectionError.timeout)
    }

    public func send(type: UInt8, body: Data) async throws {
        if isClosed { throw ConnectionError.alreadyClosed }
        let frame = Frame.encode(type: type, body: body)
        log.debug("frame tx type=0x\(String(format: "%02x", type)) len=\(frame.count)")
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
            becameReady = true
            log.debug("connection ready: \(self.endpointDescription)")
            await onReady?()
            await readLoop()
        case .failed(let err):
            log.info("connection failed (\(self.endpointDescription)): \(err.localizedDescription)")
            await closeInternal(error: err)
        case .waiting(let err):
            // 解析不到对端 / 路径不可达：NWConnection 会停在 waiting 反复重试，不会自己失败。
            // 仅记录，由上面的 establishTimeout 兜底转成失败。
            log.info("connection waiting (\(self.endpointDescription)): \(err.localizedDescription)")
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
            log.debug("frame rx type=0x\(String(format: "%02x", f.type)) len=\(f.consumed)")
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
    case timeout
}
