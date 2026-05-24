import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "drop.mesh.MeshDropKit", category: "Discovery")

/// 同网段设备发现。同时承担 responder（广告本机）与 querier（浏览其他机）。
///
/// 用法：
/// ```
/// let discovery = Discovery(identity: ..., displayName: "我的 Mac", model: "Mac15,7")
/// for await devices in discovery.devices {
///     print(devices)
/// }
/// ```
public final class Discovery: @unchecked Sendable {
    private let identity: Identity
    private let displayName: String
    private let model: String?

    private var listener: NWListener?
    private var browser: NWBrowser?

    private let lock = NSLock()
    private var _devices: [String: Device] = [:]
    private let continuation: AsyncStream<[Device]>.Continuation
    public let devices: AsyncStream<[Device]>

    /// 入站 TCP 连接钩子。由 [ShareEngine] 接管握手与业务路由。
    public var onIncomingConnection: (@Sendable (NWConnection) -> Void)?

    public init(
        identity: Identity,
        displayName: String,
        model: String? = nil,
        port: UInt16 = 0   // 0 = 让系统分配
    ) throws {
        self.identity = identity
        self.displayName = displayName
        self.model = model

        let (stream, continuation) = AsyncStream.makeStream(of: [Device].self)
        self.devices = stream
        self.continuation = continuation

        // 让 NWListener 自分配端口
        let params = NWParameters.tcp
        params.includePeerToPeer = true
        self.listener = try NWListener(using: params)
    }

    public func start() throws {
        try startResponder()
        startBrowser()
    }

    public func stop() {
        listener?.cancel()
        browser?.cancel()
        listener = nil
        browser = nil
        continuation.finish()
    }

    // MARK: - 广告本机

    private func startResponder() throws {
        guard let listener else { return }
        listener.newConnectionHandler = { [weak self] conn in
            guard let self else { conn.cancel(); return }
            if let handler = self.onIncomingConnection {
                handler(conn)
            } else {
                log.debug("dropping incoming connection (no handler): \(String(describing: conn.endpoint))")
                conn.cancel()
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                let actualPort = listener.port?.rawValue ?? 0
                log.info("listener ready on port \(actualPort)")
                // 端口已知后，正式注册 mDNS 服务
                let txt = TXTRecord.encode(
                    identity: self.identity,
                    displayName: self.displayName,
                    os: .current,
                    model: self.model,
                    port: actualPort
                )
                listener.service = NWListener.Service(
                    name: self.identity.id,             // mDNS 实例名用 device id（唯一）
                    type: TXTRecord.serviceType,
                    domain: nil,
                    txtRecord: txt
                )
            case .failed(let err):
                log.error("listener failed: \(err.localizedDescription)")
            default:
                break
            }
        }
        listener.start(queue: .main)
    }

    // MARK: - 浏览同类设备

    private func startBrowser() {
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
            type: TXTRecord.serviceType,
            domain: nil
        )
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleBrowse(results: results)
        }
        browser.stateUpdateHandler = { state in
            log.debug("browser state: \(String(describing: state))")
        }
        browser.start(queue: .main)
    }

    private func handleBrowse(results: Set<NWBrowser.Result>) {
        var seen: [String: Device] = [:]
        for result in results {
            guard case .bonjour(let txt) = result.metadata,
                  let device = TXTRecord.decode(txt) else { continue }

            // 过滤自己
            if device.id == identity.id { continue }
            seen[device.id] = device
        }

        lock.lock()
        _devices = seen
        let snapshot = Array(seen.values).sorted { $0.name < $1.name }
        lock.unlock()

        continuation.yield(snapshot)
    }

    public var currentDevices: [Device] {
        lock.lock()
        defer { lock.unlock() }
        return Array(_devices.values).sorted { $0.name < $1.name }
    }
}
