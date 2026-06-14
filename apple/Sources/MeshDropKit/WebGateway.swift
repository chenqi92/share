import Foundation
import Network
import Combine
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "WebGateway")

/// **Web Gateway**（companion-bridges.md §4.3）。
///
/// 本机充当浏览器端的"局域网桥"，监听 `0.0.0.0:<port>`：
/// - `GET /`                       → 静态 fallback UI
/// - `GET /api/v1/info`            → JSON 元数据（gateway 版本 / 配对码状态）
/// - `POST /api/v1/pair`           → 用 6 字符配对码换 session token + Set-Cookie
/// - `WS   /api/v1/control`        → 双向命令 / 事件（cookie 或 ?token=<sid>）
/// - `POST /api/v1/upload`         → multipart 上传，返回 `{token:"<absPath>"}` 作为 send_file_ref.fileRef
/// - `GET  /api/v1/download/<id>`  → 流式下载已接收的文件
///
/// 鉴权：6 字符配对码 `<两段-3字符大写字母+数字>`，配对成功后下发 24h session
/// cookie（`meshdrop_session`）与同值的 token；后续请求带 cookie 或 query
/// `?token=` / header `x-meshdrop-token` 任一即可。
///
/// **TLS 1.3**：用 P-256 自签证书 (CN=meshdrop.local)，缓存在 Keychain。
/// 浏览器首次访问需"信任并继续"（Safari "显示详细信息"→"访问此网站"；Chrome
/// "高级"→"继续前往"），之后该 host 的 trust override 写入用户 keychain。
/// 与 Windows / Linux gateway 行为一致。
public final class WebGateway: @unchecked Sendable {
    public struct Config: Sendable {
        public var host: String
        public var port: UInt16
        public var staticRoot: URL?
        public var sessionTTL: TimeInterval
        public init(
            host: String = "0.0.0.0",
            port: UInt16 = 7384,
            staticRoot: URL? = nil,
            sessionTTL: TimeInterval = 24 * 3600
        ) {
            self.host = host
            self.port = port
            self.staticRoot = staticRoot
            self.sessionTTL = sessionTTL
        }
    }

    public private(set) var config: Config
    public private(set) var pairingCode: String
    public private(set) var isRunning: Bool = false

    private let engine: ShareEngine?
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.welape.meshdrop.gateway", qos: .userInitiated)
    /// session token → expiry。
    private var sessions: [String: Date] = [:]
    private var pairingCodeIssuedAt: Date = .distantPast
    private let lock = NSLock()

    /// 配对码暴力破解防护：按来源 IP 记失败计数 + 锁定截止时间。
    private struct PairAttempt {
        var failures: Int = 0
        var lockedUntil: Date = .distantPast
    }
    private var pairAttempts: [String: PairAttempt] = [:]
    /// 连续失败这么多次后开始锁定。
    private static let pairLockThreshold = 5
    /// 锁定基准时长（指数退避：base * 2^(failures - threshold)，封顶 maxPairLock）。
    private static let pairLockBase: TimeInterval = 30
    private static let pairMaxPairLock: TimeInterval = 15 * 60
    /// 活跃 WS 连接：每个对应一对 (NWConnection, send 回调)。
    private var wsClients: [UUID: WSClient] = [:]

    private struct WSClient {
        let conn: NWConnection
        let send: (Data) -> Void
        var cancellables: Set<AnyCancellable>
    }

    public init(config: Config = .init(), engine: ShareEngine? = nil) {
        self.config = config
        self.engine = engine
        self.pairingCode = Self.generatePairingCode()
        self.pairingCodeIssuedAt = Date()
    }

    // MARK: - 生命周期

    public func start() throws {
        guard listener == nil else { return }

        // TLS 1.3 + 自签证书（meshdrop.local），与 Windows / Linux gateway 对齐
        let identity = try GatewayCertStore.loadOrCreate()
        let tlsOpts = NWProtocolTLS.Options()
        let secOpts = tlsOpts.securityProtocolOptions
        // TLS 1.3 ONLY：min 与 max 都钉死在 1.3，拒绝任何 1.2- 降级
        // （与 Windows/Linux gateway 口径统一，companion-bridges.md §4.3）。
        sec_protocol_options_set_min_tls_protocol_version(secOpts, .TLSv13)
        sec_protocol_options_set_max_tls_protocol_version(secOpts, .TLSv13)
        if let secIdentity = sec_identity_create(identity) {
            sec_protocol_options_set_local_identity(secOpts, secIdentity)
        } else {
            log.error("sec_identity_create failed for gateway SecIdentity")
        }
        // 告诉浏览器走 HTTP/1.1（我们手实装的 HTTP 不支持 h2）
        sec_protocol_options_add_tls_application_protocol(secOpts, "http/1.1")

        let params = NWParameters(tls: tlsOpts, tcp: .init())
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = false

        let port = NWEndpoint.Port(rawValue: config.port) ?? .any
        let l = try NWListener(using: params, on: port)
        l.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                log.info("WebGateway ready on :\(self?.config.port ?? 0)")
                self?.isRunning = true
            case .failed(let err):
                log.error("WebGateway failed: \(err.localizedDescription)")
                self?.isRunning = false
            case .cancelled:
                self?.isRunning = false
            default:
                break
            }
        }
        l.newConnectionHandler = { [weak self] conn in
            self?.handle(conn)
        }
        l.start(queue: queue)
        listener = l
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        lock.lock()
        let clients = wsClients
        wsClients.removeAll()
        lock.unlock()
        for (_, c) in clients { c.conn.cancel() }
    }

    public func setPort(_ port: UInt16) {
        config.port = port
    }

    public func rotatePairingCode() {
        lock.lock()
        pairingCode = Self.generatePairingCode()
        pairingCodeIssuedAt = Date()
        sessions.removeAll()
        lock.unlock()
    }

    // MARK: - 连接入口

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        readRequest(conn, buffer: Data())
    }

    private func readRequest(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buf = buffer
            if let data { buf.append(data) }

            if let headerEnd = buf.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) {
                let header = buf[..<headerEnd.lowerBound]
                let bodyTail = buf[headerEnd.upperBound...]
                if var req = HTTPRequest.parse(header: Data(header)) {
                    req.bodyTail = Data(bodyTail)
                    self.route(conn, request: req)
                } else {
                    self.respond(conn, status: 400, body: Data("bad request".utf8), close: true)
                }
                return
            }
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            if buf.count > 1024 * 1024 {
                // 1 MB header / 头部 sanity 上限
                self.respond(conn, status: 413, body: Data("payload too large".utf8), close: true)
                return
            }
            self.readRequest(conn, buffer: buf)
        }
    }

    private func route(_ conn: NWConnection, request: HTTPRequest) {
        let req = request
        let sessionToken = Self.extractToken(request: req)
        let isAuth = sessionToken.flatMap { isSessionValid($0) ? $0 : nil } != nil

        // 公开路由
        switch (req.method, req.path) {
        case ("GET", "/"):
            serveStaticIndex(conn)
            return
        case ("GET", "/api/v1/info"), ("GET", "/api/v1/version"):
            let body = #"{ "v": 1, "service": "meshdrop-gateway", "code_required": true }"#
            respond(conn, status: 200, body: Data(body.utf8), contentType: "application/json", close: true)
            return
        case ("POST", "/api/v1/pair"), ("POST", "/api/v1/auth"):
            handlePair(conn, request: req)
            return
        default:
            break
        }

        // 鉴权门
        guard isAuth else {
            respond(conn, status: 401,
                    body: Data(#"{"ok":false,"error":"unauthorized"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }

        // 路径前缀路由（download）
        if req.method == "GET" && req.path.hasPrefix("/api/v1/download/") {
            handleDownload(conn, request: req)
            return
        }

        // 鉴权后路由
        switch (req.method, req.path.split(separator: "?").first.map(String.init) ?? req.path) {
        case ("GET", "/api/v1/control"):
            if Self.isWebSocketUpgrade(req) {
                handleWebSocketUpgrade(conn, request: req)
            } else {
                respond(conn, status: 426,
                        body: Data(#"{"ok":false,"error":"expected_websocket_upgrade"}"#.utf8),
                        contentType: "application/json", close: true)
            }
        case ("POST", "/api/v1/upload"):
            handleUpload(conn, request: req)
        default:
            respond(conn, status: 404,
                    body: Data(#"{"ok":false,"error":"not_found"}"#.utf8),
                    contentType: "application/json", close: true)
        }
    }

    // MARK: - /api/v1/pair

    private func handlePair(_ conn: NWConnection, request: HTTPRequest) {
        let clientIP = Self.remoteIP(of: conn)

        // 先查该 IP 是否处于锁定窗口内（暴力破解防护）。
        if let retryAfter = pairLockoutRemaining(ip: clientIP) {
            respond(conn, status: 429,
                    body: Data(#"{"ok":false,"error":"too_many_attempts"}"#.utf8),
                    contentType: "application/json",
                    extraHeaders: ["Retry-After": String(Int(retryAfter.rounded(.up)))],
                    close: true)
            return
        }

        let lenHeader = request.headers["content-length"] ?? "0"
        guard let len = Int(lenHeader), len > 0, len < 4096 else {
            respond(conn, status: 400,
                    body: Data(#"{"ok":false,"error":"missing_body"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        readBody(conn, expected: len, accumulated: request.bodyTail) { [weak self] body in
            guard let self else { return }
            let code = Self.extractPairCode(body: body).uppercased()
            self.lock.lock()
            // 恒定时间比较：避免按比较位置泄露配对码的时序侧信道。
            let ok = Self.constantTimeEquals(code, self.pairingCode)
            self.lock.unlock()
            if ok {
                self.recordPairSuccess(ip: clientIP)
                let token = Self.newSessionToken()
                self.lock.lock()
                self.sessions[token] = Date(timeIntervalSinceNow: self.config.sessionTTL)
                self.lock.unlock()
                let body = #"{"ok":true,"token":"\#(token)"}"#
                let cookie = "meshdrop_session=\(token); Path=/; HttpOnly; Max-Age=86400; SameSite=Strict"
                self.respond(conn, status: 200,
                             body: Data(body.utf8),
                             contentType: "application/json",
                             extraHeaders: ["Set-Cookie": cookie],
                             close: true)
            } else {
                self.recordPairFailure(ip: clientIP)
                self.respond(conn, status: 401,
                             body: Data(#"{"ok":false,"error":"invalid_code"}"#.utf8),
                             contentType: "application/json",
                             close: true)
            }
        }
    }

    // MARK: - 配对码暴力破解防护

    /// 返回该 IP 当前剩余的锁定秒数；未锁定返回 nil。顺便清理已过期条目。
    private func pairLockoutRemaining(ip: String) -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        guard let a = pairAttempts[ip] else { return nil }
        let remaining = a.lockedUntil.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    private func recordPairFailure(ip: String) {
        lock.lock(); defer { lock.unlock() }
        var a = pairAttempts[ip] ?? PairAttempt()
        a.failures += 1
        if a.failures >= Self.pairLockThreshold {
            // 指数退避：30s, 60s, 120s … 封顶 15min。
            let over = a.failures - Self.pairLockThreshold
            let backoff = min(Self.pairLockBase * pow(2, Double(over)), Self.pairMaxPairLock)
            a.lockedUntil = Date(timeIntervalSinceNow: backoff)
        }
        pairAttempts[ip] = a
    }

    private func recordPairSuccess(ip: String) {
        lock.lock(); defer { lock.unlock() }
        pairAttempts.removeValue(forKey: ip)
    }

    /// 从 NWConnection 取来源 IP（去端口）。取不到时用占位 key，仍能做全局限速兜底。
    private static func remoteIP(of conn: NWConnection) -> String {
        let endpoint = conn.currentPath?.remoteEndpoint ?? conn.endpoint
        switch endpoint {
        case .hostPort(let host, _):
            switch host {
            case .ipv4(let addr): return "\(addr)"
            case .ipv6(let addr): return "\(addr)"
            case .name(let name, _): return name
            @unknown default: return String(describing: host)
            }
        default:
            return "unknown"
        }
    }

    /// 恒定时间字符串比较（按 UTF-8 字节）：长度不同也跑满较长一侧，避免提前返回泄露信息。
    static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var diff = UInt8(a.count == b.count ? 0 : 1)
        let n = max(a.count, b.count)
        var i = 0
        while i < n {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            diff |= (x ^ y)
            i += 1
        }
        return diff == 0
    }

    /// 兼容 `application/json {code:"..."}` 与 `application/x-www-form-urlencoded code=...`
    /// 与纯 plain text。
    private static func extractPairCode(body: Data) -> String {
        let raw = String(data: body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if raw.hasPrefix("{"),
           let obj = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
           let c = obj["code"] as? String {
            return c.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if raw.contains("=") {
            for kv in raw.split(separator: "&") {
                let parts = kv.split(separator: "=", maxSplits: 1)
                if parts.count == 2, parts[0] == "code" {
                    return String(parts[1])
                        .removingPercentEncoding?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? String(parts[1])
                }
            }
        }
        return raw
    }

    // MARK: - WebSocket /api/v1/control

    private func handleWebSocketUpgrade(_ conn: NWConnection, request: HTTPRequest) {
        guard let key = request.headers["sec-websocket-key"], !key.isEmpty else {
            respond(conn, status: 400,
                    body: Data(#"{"ok":false,"error":"missing_ws_key"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        let accept = WebSocketFrame.computeAccept(key: key.trimmingCharacters(in: .whitespaces))
        var head = "HTTP/1.1 101 Switching Protocols\r\n"
        head += "Upgrade: websocket\r\n"
        head += "Connection: Upgrade\r\n"
        head += "Sec-WebSocket-Accept: \(accept)\r\n\r\n"

        conn.send(content: Data(head.utf8), completion: .contentProcessed { [weak self] err in
            if let err {
                log.error("WS upgrade send failed: \(err.localizedDescription)")
                conn.cancel()
                return
            }
            self?.startWebSocketLoop(conn: conn, leftover: request.bodyTail)
        })
    }

    private func startWebSocketLoop(conn: NWConnection, leftover: Data) {
        let clientID = UUID()
        let sendFrame: (Data) -> Void = { payload in
            let frame = WebSocketFrame.text(payload)
            conn.send(content: frame, completion: .contentProcessed { _ in })
        }

        // 先注册一个空 cancellables 的 client，避免与 read loop 竞争
        lock.lock()
        wsClients[clientID] = WSClient(conn: conn, send: sendFrame, cancellables: [])
        lock.unlock()

        // 异步在 main actor 上订阅 engine 事件（推 state_snapshot 首帧 + 后续变化）
        if let engine {
            DispatchQueue.main.async { [weak self] in
                let commands = GatewayCommands(engine: engine)
                let bag = commands.subscribe(send: sendFrame)
                self?.lock.lock()
                if var client = self?.wsClients[clientID] {
                    client.cancellables = bag
                    self?.wsClients[clientID] = client
                }
                self?.lock.unlock()
            }
        }

        readWSFrame(conn: conn, clientID: clientID, buffer: leftover)
    }

    private func readWSFrame(conn: NWConnection, clientID: UUID, buffer: Data) {
        // 先尝试用已有 buffer 解析
        switch WebSocketFrame.decode(buffer: buffer) {
        case .frame(let f, let consumed):
            handleWSFrame(f, conn: conn, clientID: clientID)
            let rest = buffer.dropFirst(consumed)
            if !rest.isEmpty {
                readWSFrame(conn: conn, clientID: clientID, buffer: Data(rest))
            } else {
                readMoreWS(conn: conn, clientID: clientID, buffer: Data())
            }
        case .needsMore:
            readMoreWS(conn: conn, clientID: clientID, buffer: buffer)
        case .error(let msg):
            log.error("WS decode error: \(msg)")
            closeWS(clientID: clientID)
        }
    }

    private func readMoreWS(conn: NWConnection, clientID: UUID, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                log.info("WS recv error: \(error.localizedDescription)")
                self.closeWS(clientID: clientID)
                return
            }
            var buf = buffer
            if let data { buf.append(data) }
            if isComplete && buf.isEmpty {
                self.closeWS(clientID: clientID)
                return
            }
            self.readWSFrame(conn: conn, clientID: clientID, buffer: buf)
        }
    }

    private func handleWSFrame(_ frame: WebSocketFrame.Decoded, conn: NWConnection, clientID: UUID) {
        switch frame.opcode {
        case .text:
            guard let engine = self.engine else {
                let reply = GatewayCommands.makeReply(id: "", ok: false, error: "no_engine")
                conn.send(content: WebSocketFrame.text(reply), completion: .contentProcessed { _ in })
                return
            }
            let request = frame.payload
            // dispatch 必须在 MainActor
            DispatchQueue.main.async {
                let commands = GatewayCommands(engine: engine)
                let reply = commands.dispatch(request)
                conn.send(content: WebSocketFrame.text(reply), completion: .contentProcessed { _ in })
            }
        case .ping:
            conn.send(content: WebSocketFrame.pong(payload: frame.payload),
                      completion: .contentProcessed { _ in })
        case .close:
            conn.send(content: WebSocketFrame.close(), completion: .contentProcessed { _ in
                conn.cancel()
            })
            closeWS(clientID: clientID, cancelConn: false)
        case .pong, .binary, .continuation:
            break
        }
    }

    private func closeWS(clientID: UUID, cancelConn: Bool = true) {
        lock.lock()
        let client = wsClients.removeValue(forKey: clientID)
        lock.unlock()
        if cancelConn { client?.conn.cancel() }
    }

    // MARK: - /api/v1/upload

    private func handleUpload(_ conn: NWConnection, request: HTTPRequest) {
        let ctype = request.headers["content-type"] ?? ""
        guard let boundary = MultipartParser.boundary(fromContentType: ctype) else {
            respond(conn, status: 400,
                    body: Data(#"{"ok":false,"error":"missing_boundary"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        let lenHeader = request.headers["content-length"] ?? "0"
        guard let len = Int(lenHeader), len > 0 else {
            respond(conn, status: 400,
                    body: Data(#"{"ok":false,"error":"missing_content_length"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        // 4 GiB 上限（与 protocol/transport.md 单文件上限一致）
        if len > 4 * 1024 * 1024 * 1024 {
            respond(conn, status: 413,
                    body: Data(#"{"ok":false,"error":"payload_too_large"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        readBody(conn, expected: len, accumulated: request.bodyTail) { [weak self] body in
            guard let self else { return }
            do {
                let part = try MultipartParser.firstFilePart(body: body, boundary: boundary)
                let savedPath = try self.saveUpload(part: part)
                let resp = #"{"ok":true,"token":"\#(savedPath.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"}"#
                self.respond(conn, status: 200,
                             body: Data(resp.utf8),
                             contentType: "application/json", close: true)
            } catch {
                log.error("upload parse failed: \(error.localizedDescription)")
                self.respond(conn, status: 400,
                             body: Data(#"{"ok":false,"error":"multipart_malformed"}"#.utf8),
                             contentType: "application/json", close: true)
            }
        }
    }

    // MARK: - /api/v1/download/<historyId>

    /// 浏览器从 native 端下载已接收的文件流。
    /// path: `/api/v1/download/<historyId>`（去 query 后的路径段）。
    private func handleDownload(_ conn: NWConnection, request: HTTPRequest) {
        // 抽 path 末段（去 query）
        let path = request.path.split(separator: "?", maxSplits: 1).first.map(String.init) ?? request.path
        let prefix = "/api/v1/download/"
        guard path.hasPrefix(prefix) else {
            respond(conn, status: 400,
                    body: Data(#"{"ok":false,"error":"bad_path"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        let idStr = String(path.dropFirst(prefix.count))
        guard let historyID = UUID(uuidString: idStr) else {
            respond(conn, status: 400,
                    body: Data(#"{"ok":false,"error":"bad_history_id"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        guard let engine = self.engine else {
            respond(conn, status: 503,
                    body: Data(#"{"ok":false,"error":"no_engine"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        DispatchQueue.main.async { [weak self] in
            let commands = GatewayCommands(engine: engine)
            let lookup = commands.fileForHistory(id: historyID)
            self?.queue.async {
                guard let lookup else {
                    self?.respond(conn, status: 404,
                                  body: Data(#"{"ok":false,"error":"file_not_found"}"#.utf8),
                                  contentType: "application/json", close: true)
                    return
                }
                self?.streamFile(conn: conn, name: lookup.name, url: lookup.url)
            }
        }
    }

    /// 流式写文件：header + 分块 64 KiB read+send 直到 EOF。Range 头留 v0.2。
    private func streamFile(conn: NWConnection, name: String, url: URL) {
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = (attrs[.size] as? NSNumber)?.intValue,
              let handle = try? FileHandle(forReadingFrom: url) else {
            respond(conn, status: 410,
                    body: Data(#"{"ok":false,"error":"file_gone"}"#.utf8),
                    contentType: "application/json", close: true)
            return
        }
        let safeName = Self.rfc5987Encode(name)
        var head = "HTTP/1.1 200 OK\r\n"
        head += "Content-Type: application/octet-stream\r\n"
        head += "Content-Length: \(size)\r\n"
        head += "Content-Disposition: attachment; filename*=UTF-8''\(safeName)\r\n"
        head += "Server: MeshDrop-Gateway/0.1\r\n"
        head += "Connection: close\r\n\r\n"
        conn.send(content: Data(head.utf8), completion: .contentProcessed { [weak self] err in
            guard err == nil else {
                try? handle.close()
                conn.cancel()
                return
            }
            self?.streamChunk(conn: conn, handle: handle)
        })
    }

    private func streamChunk(conn: NWConnection, handle: FileHandle) {
        let chunk: Data
        do {
            chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
        } catch {
            try? handle.close()
            conn.cancel()
            return
        }
        if chunk.isEmpty {
            try? handle.close()
            conn.send(content: nil, isComplete: true, completion: .contentProcessed { _ in
                conn.cancel()
            })
            return
        }
        conn.send(content: chunk, completion: .contentProcessed { [weak self] err in
            if err != nil {
                try? handle.close()
                conn.cancel()
                return
            }
            self?.streamChunk(conn: conn, handle: handle)
        })
    }

    /// RFC 5987：把任意 UTF-8 文件名编码进 `Content-Disposition: filename*=UTF-8''<encoded>`
    /// 用百分号编码保护非 ASCII 与特殊字符。
    private static func rfc5987Encode(_ s: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    private func saveUpload(part: MultipartParser.FilePart) throws -> String {
        let fm = FileManager.default
        let appSupport = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
        let dir = appSupport
            .appendingPathComponent("MeshDrop", isDirectory: true)
            .appendingPathComponent("uploads", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // 文件名由客户端控制，绝不直接拼路径：剥到最后一段并剔除分隔符 / .. / 控制字符，
        // 永远落盘到 uploads 目录下（UUID 前缀防重名 + 防覆盖）。
        let safeName = Self.sanitizedUploadName(part.filename)
        let target = dir.appendingPathComponent("\(UUID().uuidString)-\(safeName)")

        // 纵深校验：canonicalize 后必须仍在 uploads 目录前缀内，否则拒绝写入。
        let uploadsRoot = dir.standardizedFileURL.path
        let standardized = target.standardizedFileURL.path
        let rootWithSep = uploadsRoot.hasSuffix("/") ? uploadsRoot : uploadsRoot + "/"
        guard standardized.hasPrefix(rootWithSep) else {
            throw MultipartParser.ParseError.malformed
        }
        try part.body.write(to: target)
        return target.path
    }

    /// 把客户端给的文件名安全化为单个路径段：
    /// 取 last path component → 剥 `/` `\` 与 NUL/控制字符 → 去掉 `..`/纯点 → 空则给 UUID。
    static func sanitizedUploadName(_ raw: String) -> String {
        // 先把 `\` 视作分隔符（Windows 客户端可能用反斜杠），再取最后一段。
        let unified = raw.replacingOccurrences(of: "\\", with: "/")
        var name = (unified as NSString).lastPathComponent
        // 剔除剩余的分隔符与控制字符（含 NUL、换行、制表）。
        name = String(name.unicodeScalars.filter { scalar in
            scalar != "/" && scalar != "\\" && !(scalar.value < 0x20) && scalar.value != 0x7F
        })
        name = name.trimmingCharacters(in: .whitespaces)
        // `.` / `..` / 空 → 用随机名兜底，杜绝目录引用。
        if name.isEmpty || name == "." || name == ".." {
            return "upload-\(UUID().uuidString)"
        }
        return name
    }

    // MARK: - body 累积

    private func readBody(
        _ conn: NWConnection,
        expected: Int,
        accumulated: Data,
        complete: @escaping (Data) -> Void
    ) {
        if accumulated.count >= expected {
            complete(accumulated.prefix(expected))
            return
        }
        let want = expected - accumulated.count
        conn.receive(minimumIncompleteLength: 1, maximumLength: min(want, 256 * 1024)) { [weak self] data, _, isComplete, _ in
            guard let self else { return }
            var buf = accumulated
            if let data { buf.append(data) }
            if buf.count >= expected || isComplete {
                complete(buf.prefix(expected))
            } else {
                self.readBody(conn, expected: expected, accumulated: buf, complete: complete)
            }
        }
    }

    // MARK: - 静态资源 / response

    private func serveStaticIndex(_ conn: NWConnection) {
        let html: Data
        if let root = config.staticRoot,
           let data = try? Data(contentsOf: root.appendingPathComponent("index.html")) {
            html = data
        } else {
            html = Self.builtInFallbackHTML().data(using: .utf8) ?? Data()
        }
        respond(conn, status: 200, body: html, contentType: "text/html; charset=utf-8", close: true)
    }

    private func respond(
        _ conn: NWConnection,
        status: Int,
        body: Data,
        contentType: String = "text/plain; charset=utf-8",
        extraHeaders: [String: String] = [:],
        close: Bool
    ) {
        let reason = Self.reason(for: status)
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Server: MeshDrop-Gateway/0.1\r\n"
        head += "Connection: close\r\n"
        for (k, v) in extraHeaders { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        var out = Data(head.utf8)
        out.append(body)
        conn.send(content: out, completion: .contentProcessed { _ in
            if close { conn.cancel() }
        })
    }

    // MARK: - session / token

    private func isSessionValid(_ token: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let exp = sessions[token] else { return false }
        if exp <= Date() {
            sessions.removeValue(forKey: token)
            return false
        }
        return true
    }

    /// 从 request 抽 token（cookie / query / header）。
    private static func extractToken(request: HTTPRequest) -> String? {
        if let cookie = request.headers["cookie"] {
            for part in cookie.split(separator: ";") {
                let kv = part.trimmingCharacters(in: .whitespaces)
                if kv.hasPrefix("meshdrop_session=") {
                    return String(kv.dropFirst("meshdrop_session=".count))
                }
            }
        }
        if let xToken = request.headers["x-meshdrop-token"], !xToken.isEmpty {
            return xToken
        }
        // ?token=<sid>
        if let q = request.path.firstIndex(of: "?") {
            let query = request.path[request.path.index(after: q)...]
            for kv in query.split(separator: "&") {
                let parts = kv.split(separator: "=", maxSplits: 1)
                if parts.count == 2, parts[0] == "token" {
                    return String(parts[1])
                        .removingPercentEncoding ?? String(parts[1])
                }
            }
        }
        return nil
    }

    private static func newSessionToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 18)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func isWebSocketUpgrade(_ req: HTTPRequest) -> Bool {
        let upgrade = req.headers["upgrade"]?.lowercased() ?? ""
        return upgrade.contains("websocket")
    }

    private static func reason(for code: Int) -> String {
        switch code {
        case 101: return "Switching Protocols"
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 413: return "Payload Too Large"
        case 426: return "Upgrade Required"
        case 501: return "Not Implemented"
        default:  return "OK"
        }
    }

    /// 6 字符配对码，格式 `LR4K7M`（避免易混淆 0/O/1/I）。
    static func generatePairingCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var out = ""
        for _ in 0..<6 {
            out.append(alphabet.randomElement()!)
        }
        return out
    }

    /// 配对码友好分隔显示。`LR4K7M` → `LR4 · K7M`
    public static func display(code: String) -> String {
        guard code.count == 6 else { return code }
        let idx = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<idx]) · \(code[idx...])"
    }

    /// 内置 placeholder。当 `staticRoot/index.html` 缺失时 fallback。
    static func builtInFallbackHTML() -> String {
        """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>MeshDrop · Web Gateway</title>
        <style>
          html, body { margin: 0; padding: 0; height: 100%; background: #F4EFE3; color: #1B1B1B;
                       font-family: -apple-system, "Helvetica Neue", "PingFang SC", sans-serif; }
          .wrap { max-width: 520px; margin: 8vh auto; padding: 32px; background: #fff;
                  border-radius: 18px; box-shadow: 0 8px 32px rgba(0,0,0,.08); }
          h1 { font-size: 28px; margin: 0 0 4px 0; letter-spacing: -.5px; }
          .tag { display: inline-block; padding: 2px 8px; border: 1px solid #C7BFAB; border-radius: 4px;
                 font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 11px; color: #6D6862; }
          p { color: #4A4742; line-height: 1.6; }
          .code-input { display: flex; gap: 8px; margin-top: 16px; }
          input { flex: 1; padding: 10px 12px; border: 1px solid #C7BFAB; border-radius: 8px;
                  font-family: ui-monospace, "SF Mono", Menlo, monospace; font-size: 16px; letter-spacing: 4px; }
          button { padding: 10px 18px; border: 0; background: #D6F26B; color: #1B1B1B;
                   border-radius: 8px; font-weight: 600; cursor: pointer; }
          .ok  { color: #4A7B1A; }
          .err { color: #B23A1A; }
          footer { margin-top: 18px; font-family: ui-monospace, monospace; font-size: 11px; color: #8C857C; }
        </style>
        </head>
        <body>
          <div class="wrap">
            <h1>MeshDrop</h1>
            <div class="tag">LAN · WEB GATEWAY · v0.1</div>
            <p>这是本机为浏览器端 MeshDrop 提供的局域网入口。请输入桌面端 <b>设置 → Web 访问</b> 中显示的 6 字符配对码。</p>
            <div class="code-input">
              <input id="code" placeholder="LR4 K7M" autocapitalize="characters" />
              <button onclick="auth()">进入</button>
            </div>
            <div id="msg" style="margin-top:10px;"></div>
            <footer>TLS 1.3 自签证书 · CN=meshdrop.local · 首次访问请在浏览器接受证书。</footer>
          </div>
        <script>
          async function auth() {
            const raw = document.getElementById('code').value.replace(/\\s|·/g, '').toUpperCase();
            const r = await fetch('/api/v1/pair', {
              method:'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ code: raw }),
              credentials: 'include',
            });
            const msg = document.getElementById('msg');
            const j = await r.json().catch(() => ({}));
            if (r.ok && j.ok) {
              msg.textContent = '✓ 配对码正确，正在连接 WS…';
              msg.className = 'ok';
              const scheme = location.protocol === 'https:' ? 'wss' : 'ws';
              const ws = new WebSocket(scheme + '://' + location.host + '/api/v1/control?token=' + encodeURIComponent(j.token || ''));
              ws.onmessage = (e) => console.log('[meshdrop] evt', e.data);
            } else {
              msg.textContent = '× 配对码不对';
              msg.className = 'err';
            }
          }
        </script>
        </body></html>
        """
    }
}

// MARK: - 极简 HTTP/1.1 parser

struct HTTPRequest {
    var method: String
    var path: String
    var headers: [String: String]
    /// header 解析后剩在 buffer 里的尾段（body 起始）。
    var bodyTail: Data

    static func parse(header: Data) -> HTTPRequest? {
        guard let text = String(data: header, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return nil }
        let parts = lines[0].split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() where !line.isEmpty {
            if let colon = line.firstIndex(of: ":") {
                let k = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let v = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[k] = v
            }
        }
        return HTTPRequest(
            method: String(parts[0]),
            path: String(parts[1]),
            headers: headers,
            bodyTail: Data()
        )
    }
}
