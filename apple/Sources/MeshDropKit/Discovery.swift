import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "Discovery")

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
    public static let peerToPeerServiceType = "_meshdrop-p2p._tcp"
    private let peerToPeer: Bool
    private var serviceType: String { peerToPeer ? Self.peerToPeerServiceType : TXTRecord.serviceType }

    private var listener: NWListener?
    private var browser: NWBrowser?

    /// 监听器就绪后系统分配的实际端口；用于在 setAdvertising 重新发布 mDNS 服务时重建 TXT。
    private var advertisedPort: UInt16 = 0
    /// 「局域网可见」状态：true=发布 mDNS 服务可被发现；false=撤下服务（listener 仍在跑、
    /// 已建连接不受影响、浏览他机不受影响）。默认 true，保持现有广告行为。
    private var advertising: Bool = true

    private let lock = NSLock()
    private var _devices: [String: Device] = [:]
    private let continuation: AsyncStream<[Device]>.Continuation
    public let devices: AsyncStream<[Device]>

    /// 入站 TCP 连接钩子。由 [ShareEngine] 接管握手与业务路由。
    public var onIncomingConnection: (@Sendable (NWConnection) -> Void)?

    /// 发现层致命错误（listener/browser 失败，最常见是本地网络权限被拒）。
    /// 由 [ShareEngine] 接管并反映到 UI，避免「看着在等配对、实际没在广播」的无限加载。
    public var onError: (@Sendable (String) -> Void)?

    public init(
        identity: Identity,
        displayName: String,
        model: String? = nil,
        port: UInt16 = 0,   // 0 = 让系统分配
        peerToPeer: Bool = false
    ) throws {
        self.identity = identity
        self.displayName = displayName
        self.model = model
        self.peerToPeer = peerToPeer

        let (stream, continuation) = AsyncStream.makeStream(of: [Device].self)
        self.devices = stream
        self.continuation = continuation

        // Keep the legacy LAN advertisement independent of the AWDL service.
        // iOS LAN discovery retains its existing peer-to-peer opt-in.
        let params = try TransportSecurity.parameters(identity: identity)
        #if os(macOS)
        params.includePeerToPeer = peerToPeer
        #else
        params.includePeerToPeer = true
        #endif
        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port) ?? .any)
    }

    public func start() throws {
        try startResponder()
        startBrowser()
    }

    public func stop() {
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        browser?.stateUpdateHandler = nil
        browser?.browseResultsChangedHandler = nil
        listener?.cancel()
        browser?.cancel()
        listener = nil
        browser = nil
        continuation.finish()
    }

    /// 切换「局域网可见」：附加式能力，不影响 listener 收发与 browser 浏览。
    /// enabled=true → 发布 mDNS 服务（可被发现）；false → 撤下服务（不再被发现，
    /// 但已建连接不强断、仍可接受新入站连接、仍能浏览他机）。
    /// 若 listener 尚未 ready（端口未知），只记录标志，待 .ready 时按此决定是否发布。
    public func setAdvertising(enabled: Bool) {
        lock.lock()
        advertising = enabled
        let port = advertisedPort
        lock.unlock()
        guard let listener else { return }
        if enabled {
            guard port != 0 else { return } // 端口未就绪，留给 .ready 发布
            listener.service = NWListener.Service(
                name: identity.id,
                type: serviceType,
                domain: nil,
                txtRecord: makeTXT(port: port)
            )
        } else {
            // 撤下服务（停止 mDNS 广告），listener 本身继续运行。
            listener.service = nil
        }
    }

    private func makeTXT(port: UInt16) -> NWTXTRecord {
        TXTRecord.encode(
            identity: identity,
            displayName: displayName,
            os: .current,
            model: model,
            port: port
        )
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
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self, let listener else { return }
            switch state {
            case .ready:
                let actualPort = listener.port?.rawValue ?? 0
                log.info("listener ready on port \(actualPort)")
                self.lock.lock()
                self.advertisedPort = actualPort
                let shouldAdvertise = self.advertising
                self.lock.unlock()
                // 端口已知后，按「局域网可见」状态决定是否注册 mDNS 服务。
                // 关闭时 listener 照常接受入站连接，只是不发布服务（不被发现）。
                if shouldAdvertise {
                    listener.service = NWListener.Service(
                        name: self.identity.id,             // mDNS 实例名用 device id（唯一）
                        type: self.serviceType,
                        domain: nil,
                        txtRecord: self.makeTXT(port: actualPort)
                    )
                }
            case .waiting(let err), .failed(let err):
                log.error("listener \(self.serviceType, privacy: .public) failed: \(err.localizedDescription, privacy: .public)")
                self.onError?(L10n.discoveryUnavailable)
            default:
                break
            }
        }
        listener.start(queue: .main)
    }

    // MARK: - 浏览同类设备

    private func startBrowser() {
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
            type: serviceType,
            domain: nil
        )
        let params = NWParameters()
        // Match the corresponding listener's interface scope.
        #if os(macOS)
        params.includePeerToPeer = peerToPeer
        #else
        params.includePeerToPeer = true
        #endif
        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.handleBrowse(results: results)
        }
        browser.stateUpdateHandler = { [weak self] state in
            log.debug("browser state: \(String(describing: state))")
            switch state {
            case .waiting(let err), .failed(let err):
                log.error("browser \(self?.serviceType ?? "unknown", privacy: .public) failed: \(err.localizedDescription, privacy: .public)")
                self?.onError?(L10n.discoveryUnavailable)
            default:
                break
            }
        }
        browser.start(queue: .main)
    }

    private func handleBrowse(results: Set<NWBrowser.Result>) {
        var seen: [String: Device] = [:]
        for result in results {
            guard case .bonjour(let txt) = result.metadata,
                  var device = TXTRecord.decode(txt, endpoint: result.endpoint) else { continue }

            if peerToPeer {
                // Bind to AWDL explicitly: selecting Apple direct must never silently
                // send over the router just because both devices also have LAN access.
                guard let interface = result.interfaces.first(where: { $0.name.hasPrefix("awdl") }),
                      case let .service(name, type, domain, _) = result.endpoint else { continue }
                device.discoveryEndpoint = nil
                device.peerToPeerEndpoint = .service(name: name, type: type, domain: domain, interface: interface)
            }

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
