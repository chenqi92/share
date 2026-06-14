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

        // 让 NWListener 自分配端口。
        // 不启用 peer-to-peer（AWDL）：本工具走同网段基础 Wi-Fi 发现；在 macOS 沙盒下启用 P2P
        // 会让 Bonjour 只广告 link-local IPv6、不广告可路由 IPv4，对端能发现却连不上。
        let params = NWParameters.tcp
        params.includePeerToPeer = false
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
                type: TXTRecord.serviceType,
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
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
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
                        type: TXTRecord.serviceType,
                        domain: nil,
                        txtRecord: self.makeTXT(port: actualPort)
                    )
                }
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
        params.includePeerToPeer = false
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
