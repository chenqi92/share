import Foundation
import Network
import Security
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "Connection")

/// 包装 TCP 或蓝牙 L2CAP 连接，提供按帧 (`Frame`) 读写的串行化接口。
///
/// - 由 actor 保证串行；上层不需要自己加锁。
/// - 读循环在 NWConnection 进入 `.ready` 后启动，按 [transport.md](../../../protocol/transport.md)
///   的 framing 规范解出 (type, body) 投给 `onMessage`。
/// - 任一侧关闭、出错都会触发 `onClose`，触发后不再有任何回调。
public actor Connection {
    private var nw: NWConnection?
    private var stream: StreamTransport?
    private var tlsChannel: BluetoothTLSChannel?
    private var bluetoothSecurity: (Identity, BluetoothTLSChannel.Role)?
    private let openStream: (@Sendable () async throws -> StreamTransport)?
    public nonisolated let route: TransferRoute
    private nonisolated let endpointName: String
    private var readBuffer = Data()
    private var isClosed = false
    private var becameReady = false
    private var needsBluetoothFlush = false
    private var pendingPongs = 0
    private var bluetoothCloseDeadline: Task<Void, Never>?
    private static let heartbeatBody = Data("{}".utf8)
    public private(set) var authenticatedFingerprint: String?

    /// 建连 + 进入 ready 的整体超时。service endpoint 解析不到对端 / 对端不可达时
    /// NWConnection 会停在 `.waiting`（不会自己 `.failed`），没有超时就会永远挂着，
    /// 上层 UI 表现为「无限加载」。超过此时限仍未 ready 即按超时失败。
    private static let establishTimeout: TimeInterval = 12

    private var onMessage: ((UInt8, Data) async -> Void)?
    private var onClose: ((Error?) async -> Void)?
    private var onReady: (() async -> Void)?

    /// 远端 endpoint 字符串，主要用于日志。
    public nonisolated var endpointDescription: String {
        endpointName
    }

    public init(nwConnection: NWConnection, route: TransferRoute = .lan) {
        self.nw = nwConnection
        self.openStream = nil
        self.route = route
        self.endpointName = String(describing: nwConnection.endpoint)
    }

    init(bluetooth open: @escaping @Sendable () async throws -> StreamTransport, identity: Identity, role: BluetoothTLSChannel.Role) {
        bluetoothSecurity = (identity, role)
        nw = nil
        openStream = open
        route = .bluetooth
        endpointName = "Bluetooth L2CAP"
    }

    init(unavailable route: TransferRoute) {
        nw = nil
        openStream = { throw ConnectionError.routeUnavailable }
        self.route = route
        endpointName = route.rawValue
    }

    /// 用目标设备建一条出方连接。
    public init(connectingTo device: Device, route: TransferRoute = .lan, identity: Identity = IdentityStore.loadOrCreate()) {
        if route == .bluetooth || (route == .peerToPeer && device.peerToPeerEndpoint == nil) {
            nw = nil
            openStream = { throw ConnectionError.routeUnavailable }
            self.route = route
            endpointName = route.rawValue
            return
        }
        let params: NWParameters
        do { params = try TransportSecurity.parameters(identity: identity, expectedFingerprint: device.fingerprint) }
        catch {
            nw = nil
            openStream = { throw TransportSecurity.Failure.invalidIdentity }
            self.route = route
            endpointName = route.rawValue
            return
        }
        params.includePeerToPeer = true
        let endpoint = (route == .peerToPeer ? device.peerToPeerEndpoint : device.discoveryEndpoint) ?? NWEndpoint.service(
            name: device.id,
            type: TXTRecord.serviceType,
            domain: "local",
            interface: nil
        )
        if route == .peerToPeer {
            guard case let .service(_, _, _, interface?) = endpoint,
                  interface.name.hasPrefix("awdl") else {
                nw = nil
                openStream = { throw ConnectionError.routeUnavailable }
                self.route = route
                endpointName = route.rawValue
                return
            }
            params.requiredInterface = interface
        }
        self.nw = NWConnection(to: endpoint, using: params)
        self.openStream = nil
        self.route = route
        self.endpointName = String(describing: endpoint)
    }

    public func start(
        onReady: @escaping () async -> Void,
        onMessage: @escaping (UInt8, Data) async -> Void,
        onClose: @escaping (Error?) async -> Void
    ) {
        self.onReady = onReady
        self.onMessage = onMessage
        self.onClose = onClose

        if let nw {
            startTLS(nw)
        } else {
            Task { await self.startStream() }
        }

        // 建连超时兜底：N 秒内没进入 ready 就按超时失败，避免停在 .waiting/.preparing 无限挂起。
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.route == .bluetooth ? 95 : Self.establishTimeout) * 1_000_000_000))
            await self?.failIfNotReady()
        }
    }

    private func startStream() async {
        do {
            guard let openStream else { throw ConnectionError.alreadyClosed }
            let transport = try await openStream()
            guard !isClosed else { await transport.close(); return }
            stream = transport
            try await transport.start()
            guard !isClosed else { return }
            guard let (identity, role) = bluetoothSecurity else { throw TransportSecurity.Failure.invalidIdentity }
            let channel = try await BluetoothTLSChannel(stream: transport, identity: identity, role: role)
            guard !isClosed else { await channel.close(); return }
            tlsChannel = channel
            await channel.start(onTLS: { [weak self] connection in
                guard let self else { connection.cancel(); return }
                Task { await self.startTLS(connection) }
            }, onFailure: { [weak self] error in
                Task { await self?.closeInternal(error: error) }
            })
        } catch { await closeInternal(error: error) }
    }

    private func startTLS(_ connection: NWConnection) {
        guard !isClosed else { connection.cancel(); return }
        nw = connection
        connection.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleNWState(state) }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }

    private func failIfNotReady() async {
        guard !becameReady, !isClosed else { return }
        log.info("connection establish timeout: \(self.endpointDescription)")
        await closeInternal(error: ConnectionError.timeout)
    }

    public func send(type: UInt8, body: Data) async throws {
        guard becameReady, !isClosed, bluetoothCloseDeadline == nil else { throw ConnectionError.alreadyClosed }
        if route == .bluetooth {
            if type == MessageType.ping { pendingPongs += 1 }
            else if type != MessageType.pong { needsBluetoothFlush = true }
        }
        let frame = Frame.encode(type: type, body: body)
        log.debug("frame tx type=0x\(String(format: "%02x", type)) len=\(frame.count)")
        guard let nw else { throw ConnectionError.alreadyClosed }
        try await nw.writeChunk(frame)
    }

    public func close() async {
        guard !isClosed, bluetoothCloseDeadline == nil else { return }
        guard needsBluetoothFlush, let nw else {
            await closeInternal(error: nil)
            return
        }
        // A successful local TLS write can still be buffered ahead of L2CAP.
        // PONG confirms the remote endpoint consumed every preceding frame.
        pendingPongs += 1
        bluetoothCloseDeadline = Task {
            do { try await Task.sleep(for: .seconds(90)) } catch { return }
            await closeInternal(error: ConnectionError.timeout)
        }
        do { try await nw.writeChunk(Frame.encode(type: MessageType.ping, body: Self.heartbeatBody)) }
        catch { await closeInternal(error: error) }
    }

    func abort() async {
        await closeInternal(error: nil)
    }

    // MARK: - 内部

    private func handleNWState(_ state: NWConnection.State) async {
        guard !isClosed else { return }
        switch state {
        case .ready:
            guard let metadata = nw?.metadata(definition: NWProtocolTLS.definition) as? NWProtocolTLS.Metadata,
                  sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata.securityProtocolMetadata) == .TLSv13,
                  let negotiated = sec_protocol_metadata_get_negotiated_protocol(metadata.securityProtocolMetadata),
                  String(cString: negotiated) == "meshdrop/1",
                  let fingerprint = TransportSecurity.peerFingerprint(metadata.securityProtocolMetadata) else {
                await closeInternal(error: TransportSecurity.Failure.invalidIdentity)
                return
            }
            authenticatedFingerprint = fingerprint
            becameReady = true
            let interfaces = nw?.currentPath?.availableInterfaces.map(\.name).joined(separator: ",") ?? ""
            log.info("connection ready route=\(self.route.rawValue, privacy: .public) interfaces=\(interfaces, privacy: .public) security=TLS1.3")
            await onReady?()
            await readLoop()
        case .failed(let err):
            log.info("connection failed (\(self.endpointDescription)): \(err.localizedDescription)")
            await closeInternal(error: { if case .tls = err { return TransportSecurity.Failure.invalidIdentity }; return err }())
        case .waiting(let err):
            if case .tls = err {
                await closeInternal(error: TransportSecurity.Failure.invalidIdentity)
                return
            }
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
                guard let chunk = try await nw?.readChunk() else {
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
            if f.type == MessageType.ping {
                try await nw?.writeChunk(Frame.encode(type: MessageType.pong, body: Self.heartbeatBody))
            } else if f.type == MessageType.pong, pendingPongs > 0 {
                pendingPongs -= 1
                if pendingPongs == 0, bluetoothCloseDeadline != nil {
                    await closeInternal(error: nil)
                    return
                }
            }
            if bluetoothCloseDeadline == nil { await onMessage?(f.type, f.body) }
        }
    }

    private func closeInternal(error: Error?) async {
        if isClosed { return }
        isClosed = true
        bluetoothCloseDeadline?.cancel()
        bluetoothCloseDeadline = nil
        nw?.cancel()
        await tlsChannel?.close()
        await stream?.close(error: error)
        await onClose?(error)
        onMessage = nil
        onClose = nil
        onReady = nil
    }
}

extension NWConnection {
    func readChunk() async throws -> Data? {
        return try await withCheckedThrowingContinuation { cont in
            receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { data, _, isComplete, error in
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

    func writeChunk(_ data: Data?) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            send(content: data, contentContext: data == nil ? .finalMessage : .defaultMessage, isComplete: true, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }
}

public enum ConnectionError: Error, LocalizedError {
    case alreadyClosed
    case timeout
    case bufferFull
    case routeUnavailable

    public var errorDescription: String? {
        switch self {
        case .alreadyClosed: return String(localized: "connection.closed", bundle: .module)
        case .timeout: return String(localized: "connection.timeout", bundle: .module)
        case .bufferFull: return String(localized: "connection.busy", bundle: .module)
        case .routeUnavailable: return String(localized: "connection.routeUnavailable", bundle: .module)
        }
    }
}
