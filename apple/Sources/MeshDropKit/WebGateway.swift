import Foundation
import Network
import OSLog

private let log = Logger(subsystem: "com.welape.meshdrop", category: "WebGateway")

/// **Web Gateway**（companion-bridges.md §4.3）。
///
/// 本机充当浏览器端的"局域网桥"，监听 `0.0.0.0:<port>`，提供：
/// - `GET /` → 静态 fallback UI
/// - `GET /api/v1/info` → JSON 元数据（gateway 版本 / 主机名 / 配对码状态）
/// - `WS  /api/v1/control` → 控制通道（**v0.2 实装**）
/// - `POST /api/v1/upload`  → multipart 文件上传前置（**v0.2**）
/// - `GET  /api/v1/download/<offerId>` → 下载流（**v0.2**）
///
/// 鉴权：6 字符配对码 `<两段-3字符大写字母+数字>`，每 24h 重新生成。
/// 浏览器首次访问时填入弹框，校验通过后下发 24h session cookie。
///
/// **TLS**：当前 v0.1 走明文 HTTP（便于本机 / LAN 调试与首版互通验证）；
/// 自签证书 + CN=`meshdrop.local` 留待 v0.2 — 见 PR 说明的 PROTOCOL ISSUE。
/// 自签实装时只需在 `bind()` 里把 `NWParameters.tcp` 改成带 `sec_protocol_options`
/// 的 TLS 参数，路由与会话逻辑无需变。
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

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.welape.meshdrop.gateway", qos: .userInitiated)
    private var sessions: Set<String> = []
    private var pairingCodeIssuedAt: Date = .distantPast
    private let lock = NSLock()

    public init(config: Config = .init()) {
        self.config = config
        self.pairingCode = Self.generatePairingCode()
        self.pairingCodeIssuedAt = Date()
    }

    // MARK: - 生命周期

    public func start() throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
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

    // MARK: - 连接处理

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        readRequest(conn, buffer: Data())
    }

    private func readRequest(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buf = buffer
            if let data { buf.append(data) }

            // 简单 HTTP/1.1：检测 CRLFCRLF 即视为 header 完整
            if let headerEnd = buf.range(of: Data([0x0d, 0x0a, 0x0d, 0x0a])) {
                let header = buf[..<headerEnd.lowerBound]
                let bodyTail = buf[headerEnd.upperBound...]
                var req = HTTPRequest.parse(header: Data(header))
                req?.bodyTail = Data(bodyTail)
                self.route(conn, request: req)
                return
            }
            if isComplete || error != nil {
                conn.cancel()
                return
            }
            if buf.count > 64 * 1024 {
                self.respond(conn, status: 413, body: Data("payload too large".utf8), close: true)
                return
            }
            self.readRequest(conn, buffer: buf)
        }
    }

    private func route(_ conn: NWConnection, request: HTTPRequest?) {
        guard let req = request else {
            respond(conn, status: 400, body: Data("bad request".utf8), close: true)
            return
        }
        switch (req.method, req.path) {
        case ("GET", "/"):
            serveStaticIndex(conn)
        case ("GET", "/api/v1/info"):
            let body = """
            { "v": 1, "service": "meshdrop-gateway", "code_required": true }
            """.data(using: .utf8) ?? Data()
            respond(conn, status: 200, body: body, contentType: "application/json", close: true)
        case ("POST", "/api/v1/auth"):
            // v0.2 实装真正的 cookie 颁发；当前先做 stub，仅在收到正确码时返回 200
            handleAuth(conn, request: req)
        case ("GET", "/api/v1/control"),
             ("POST", "/api/v1/upload"):
            // WS / upload — v0.2
            respond(conn, status: 501, body: Data("not implemented in v0.1".utf8), close: true)
        default:
            if req.method == "GET" && req.path.hasPrefix("/api/v1/download/") {
                respond(conn, status: 501, body: Data("not implemented in v0.1".utf8), close: true)
            } else {
                respond(conn, status: 404, body: Data("not found".utf8), close: true)
            }
        }
    }

    private func handleAuth(_ conn: NWConnection, request: HTTPRequest) {
        // 读 body：Content-Length
        let lenHeader = request.headers["content-length"] ?? "0"
        guard let len = Int(lenHeader), len > 0, len < 4096 else {
            respond(conn, status: 400, body: Data("missing body".utf8), close: true)
            return
        }
        readBody(conn, expected: len, accumulated: request.bodyTail) { [weak self] body in
            guard let self else { return }
            let submitted = String(data: body, encoding: .utf8) ?? ""
            let trimmed = submitted.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            self.lock.lock()
            let ok = trimmed == self.pairingCode
            self.lock.unlock()
            if ok {
                self.respond(conn, status: 200, body: Data("{\"ok\":true}".utf8), contentType: "application/json", close: true)
            } else {
                self.respond(conn, status: 401, body: Data("{\"ok\":false,\"error\":\"invalid_code\"}".utf8), contentType: "application/json", close: true)
            }
        }
    }

    private func readBody(_ conn: NWConnection, expected: Int, accumulated: Data, complete: @escaping (Data) -> Void) {
        if accumulated.count >= expected {
            complete(accumulated.prefix(expected))
            return
        }
        conn.receive(minimumIncompleteLength: 1, maximumLength: expected - accumulated.count) { data, _, isComplete, _ in
            var buf = accumulated
            if let data { buf.append(data) }
            if buf.count >= expected || isComplete {
                complete(buf)
            } else {
                self.readBody(conn, expected: expected, accumulated: buf, complete: complete)
            }
        }
    }

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

    private func respond(_ conn: NWConnection, status: Int, body: Data, contentType: String = "text/plain; charset=utf-8", close: Bool) {
        let reason = Self.reason(for: status)
        var head = "HTTP/1.1 \(status) \(reason)\r\n"
        head += "Content-Type: \(contentType)\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Server: MeshDrop-Gateway/0.1\r\n"
        head += "Connection: close\r\n"
        head += "\r\n"
        var out = Data(head.utf8)
        out.append(body)
        conn.send(content: out, completion: .contentProcessed { _ in
            if close { conn.cancel() }
        })
    }

    // MARK: - 辅助

    private static func reason(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 404: return "Not Found"
        case 413: return "Payload Too Large"
        case 501: return "Not Implemented"
        default:  return "OK"
        }
    }

    /// 6 字符配对码，格式 `LR4K7M`（2 段 3 字符，避免易混淆 0/O/1/I）。
    static func generatePairingCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var out = ""
        for i in 0..<6 {
            if i == 3 { out += "" }  // 显示时插 ·，存储仍是 6 字符
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
            <footer>注：v0.1 仅校验配对码；WebSocket 控制通道（/api/v1/control）将在 v0.2 启用，届时启用 TLS 自签证书。</footer>
          </div>
        <script>
          async function auth() {
            const raw = document.getElementById('code').value.replace(/\\s|·/g, '').toUpperCase();
            const r = await fetch('/api/v1/auth', { method:'POST', body: raw });
            const msg = document.getElementById('msg');
            if (r.ok) { msg.textContent = '✓ 配对码正确（WS 通道 v0.2 启用）'; msg.className = 'ok'; }
            else      { msg.textContent = '× 配对码不对'; msg.className = 'err'; }
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
