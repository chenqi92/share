using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Reflection;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using MeshDrop.Transport;

namespace MeshDrop.Gateway;

/// <summary>
/// MeshDrop Web Gateway。监听 0.0.0.0:7384 (https + WebSocket)。
/// 实装 protocol/companion-bridges.md §4.3：
///   - GET /                    → web-fallback/index.html (内嵌资源)
///   - POST /api/v1/pair        → 验 pairing code，下发 session cookie + token（companion-bridges §4.3）
///                                 别名 /api/v1/auth 保留兼容旧客户端
///   - WS  /api/v1/control      → 双向命令 / 事件通道（cookie / ?token= / x-meshdrop-token 任一鉴权）
///   - POST /api/v1/upload      → multipart 暂存文件，返 token
///   - GET  /api/v1/download/{} → 接受 offer 后下载流（v0.1：本地保存路径）
///
/// 用 TcpListener + SslStream + System.Net.WebSockets 手搭，
/// 不引第三方 web framework。
/// </summary>
public sealed class WebGatewayHost
{
    public const ushort DefaultPort = 7384;

    /// <summary>未鉴权请求体上限（仅 /api/v1/pair 这类 pre-auth 路由用）。
    /// 限制 Content-Length 防止匿名客户端发超大 body 撑爆内存（DoS）。</summary>
    private const int MaxPreAuthBodyBytes = 8 * 1024;

    /// <summary>配对码爆破防护：单 IP 连续失败 5 次锁定 5 分钟。</summary>
    private const int PairMaxFailures = 5;
    private static readonly TimeSpan PairLockout = TimeSpan.FromMinutes(5);

    private readonly ShareEngine _engine;
    private readonly GatewayCommands _commands;
    private readonly PairingCodeStore _pairingStore = new();
    private readonly ConcurrentDictionary<string, DateTimeOffset> _sessions = new();
    // 死连接必须真正移除（fix #79）：ConcurrentBag 无 Remove，会单调泄漏。
    private readonly ConcurrentDictionary<Guid, WebSocket> _wsClients = new();
    // per-IP 配对失败计数（fix #93）：(失败次数, 锁定截止时刻)。
    private readonly ConcurrentDictionary<string, (int fails, DateTimeOffset until)> _pairFailures = new();
    private readonly ushort _port;

    private TcpListener? _listener;
    private CancellationTokenSource? _cts;
    private X509Certificate2? _cert;

    public bool IsRunning { get; private set; }
    public string PairingCode => _pairingStore.Code;

    public string Url
    {
        get
        {
            var ip = _engine.LocalIp;
            if (string.IsNullOrEmpty(ip) || ip == "—") ip = "<your-lan-ip>";
            return $"https://{ip}:{_port}";
        }
    }

    public WebGatewayHost(ShareEngine engine, ushort port = DefaultPort)
    {
        _engine = engine;
        _port = port;
        _commands = new GatewayCommands(engine);
    }

    public Task StartAsync()
    {
        if (IsRunning) return Task.CompletedTask;
        try
        {
            _cert = GatewayCert.LoadOrCreate();
            _listener = new TcpListener(IPAddress.Any, _port);
            _listener.Start();
            _cts = new CancellationTokenSource();
            _ = AcceptLoopAsync(_cts.Token);
            _engine.Event += OnEngineEvent;
            IsRunning = true;
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[gateway] start failed: {ex}");
            try { _listener?.Stop(); } catch { }
            _listener = null;
        }
        return Task.CompletedTask;
    }

    public void Stop()
    {
        if (!IsRunning) return;
        _engine.Event -= OnEngineEvent;
        try { _cts?.Cancel(); } catch { }
        try { _listener?.Stop(); } catch { }
        _listener = null;
        IsRunning = false;
        foreach (var ws in _wsClients.Values)
        {
            try { ws.Abort(); } catch { }
            try { ws.Dispose(); } catch { }
        }
        _wsClients.Clear();
    }

    private async Task AcceptLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested && _listener is not null)
        {
            TcpClient client;
            try { client = await _listener.AcceptTcpClientAsync(ct); }
            catch (OperationCanceledException) { break; }
            catch { break; }
            _ = Task.Run(() => HandleClientAsync(client, ct));
        }
    }

    private async Task HandleClientAsync(TcpClient tcp, CancellationToken ct)
    {
        using var _ = tcp;
        SslStream? ssl = null;
        try
        {
            ssl = new SslStream(tcp.GetStream(), leaveInnerStreamOpen: false);
            // TLS 1.3 ONLY（protocol/security.md + README 声明）：不允许降级到 1.2。
            await ssl.AuthenticateAsServerAsync(_cert!, clientCertificateRequired: false,
                                                System.Security.Authentication.SslProtocols.Tls13,
                                                checkCertificateRevocation: false);

            var (method, path, headers, reader) = await ReadHeadersAsync(ssl, ct);
            if (method is null || reader is null) return;

            var sessionId = ExtractSessionToken(path, headers);
            var isAuth = !string.IsNullOrEmpty(sessionId) && IsSessionValid(sessionId);

            // 已声明的 body 长度（用于按鉴权状态分级限流，pre-auth 严格上限防 DoS）。
            var declaredLen = 0;
            if (headers.TryGetValue("Content-Length", out var clStr)) int.TryParse(clStr, out declaredLen);

            // 路由
            if (method == "GET" && path == "/")
            {
                await WriteHtmlAsync(ssl, FallbackHtml(), ct);
                return;
            }
            // 与 Linux / Apple gateway 对齐：/api/v1/pair 是规范名；/api/v1/auth 是旧别名
            if (method == "POST" && (path == "/api/v1/pair" || path == "/api/v1/auth"))
            {
                var clientIp = RemoteIp(tcp);
                // 爆破锁定：失败过多的 IP 暂时拒绝，连读 body 都不读。
                if (IsPairLockedOut(clientIp))
                {
                    await WriteJsonAsync(ssl, 429, "{\"ok\":false,\"error\":\"too_many_attempts\"}", ct);
                    return;
                }
                // pre-auth：拒绝超大 body，避免匿名 OOM。
                if (declaredLen > MaxPreAuthBodyBytes)
                {
                    await WriteJsonAsync(ssl, 413, "{\"ok\":false,\"error\":\"payload_too_large\"}", ct);
                    return;
                }
                var body = await reader.ReadBytesAsync(declaredLen, ct);
                var code = ExtractAuthCode(body);
                if (_pairingStore.Verify(code))
                {
                    ResetPairFailures(clientIp);
                    var sid = NewSessionId();
                    _sessions[sid] = DateTimeOffset.UtcNow.AddHours(24);
                    // body 含 token：web 客户端把它存 localStorage 再以 ?token= / x-meshdrop-token 用；
                    // 同时 Set-Cookie 让浏览器自动带（companion-bridges §4.3）
                    var bodyJson = $"{{\"ok\":true,\"token\":\"{sid}\"}}";
                    await WriteResponseAsync(ssl, 200, "OK",
                        new Dictionary<string, string>
                        {
                            ["Content-Type"] = "application/json; charset=utf-8",
                            ["Set-Cookie"] = $"meshdrop_session={sid}; Path=/; HttpOnly; Secure; Max-Age=86400; SameSite=Strict",
                        },
                        Encoding.UTF8.GetBytes(bodyJson), ct);
                }
                else
                {
                    RecordPairFailure(clientIp);
                    await WriteJsonAsync(ssl, 401, "{\"ok\":false,\"error\":\"invalid_code\"}", ct);
                }
                return;
            }

            if (!isAuth)
            {
                await WriteJsonAsync(ssl, 401, "{\"ok\":false,\"error\":\"unauthorized\"}", ct);
                return;
            }

            if (method == "GET" && path == "/api/v1/control" && IsWebSocketUpgrade(headers))
            {
                await UpgradeAndServeWebSocketAsync(ssl, headers, ct);
                return; // WebSocket 用完之后流由 WS 关闭，外层不再 dispose
            }
            if (method == "POST" && path == "/api/v1/upload")
            {
                // 流式落盘到 LocalAppData/uploads/<guid>，不把整个 body 读进内存（避免大文件 OOM）。
                var tokenPath = await SaveUploadAsync(reader, declaredLen, ct);
                var escapedToken = tokenPath.Replace("\\", "\\\\").Replace("\"", "\\\"");
                await WriteJsonAsync(ssl, 200,
                    $"{{\"ok\":true,\"token\":\"{escapedToken}\",\"uploadToken\":\"{escapedToken}\"}}", ct);
                return;
            }
            if (method == "GET" && path.StartsWith("/api/v1/download/"))
            {
                await HandleDownloadAsync(ssl, path, ct);
                return;
            }

            await WriteResponseAsync(ssl, 404, "Not Found", new(), Encoding.UTF8.GetBytes("not found"), ct);
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"[gateway] handler error: {ex.Message}");
        }
        finally
        {
            try { ssl?.Dispose(); } catch { }
        }
    }

    // ─── /api/v1/download/<historyId> ──────────────────────────────────

    /// <summary>
    /// 流式下载已接收文件（companion-bridges.md §4.3）。
    /// path: /api/v1/download/<uuid>
    /// </summary>
    private async Task HandleDownloadAsync(SslStream ssl, string path, CancellationToken ct)
    {
        var idStr = path.Substring("/api/v1/download/".Length).Split('?')[0];
        if (!Guid.TryParse(idStr, out var historyId))
        {
            await WriteJsonAsync(ssl, 400, "{\"ok\":false,\"error\":\"bad_history_id\"}", ct);
            return;
        }

        // 扫 ObservableCollection 找 incoming file（只读，访问主线程更安全；engine.History
        // 是 ObservableCollection 直接 LINQ 在当前线程读够用，跨端约定主线程改写、子线程读）
        var item = _engine.History.FirstOrDefault(h =>
            h.Id == historyId &&
            h.Direction == Models.TransferDirection.Incoming);
        if (item is null || item.Kind is not Models.HistoryKind.File file ||
            string.IsNullOrEmpty(file.LocalPath) || !System.IO.File.Exists(file.LocalPath))
        {
            await WriteJsonAsync(ssl, 404, "{\"ok\":false,\"error\":\"file_not_found\"}", ct);
            return;
        }

        var info = new FileInfo(file.LocalPath);
        var safeName = Rfc5987Encode(file.Name);
        var head = "HTTP/1.1 200 OK\r\n"
                 + "Content-Type: application/octet-stream\r\n"
                 + $"Content-Length: {info.Length}\r\n"
                 + $"Content-Disposition: attachment; filename*=UTF-8''{safeName}\r\n"
                 + "Server: MeshDrop-Gateway-Win/0.1\r\n"
                 + "Connection: close\r\n\r\n";
        var headBytes = Encoding.ASCII.GetBytes(head);
        await ssl.WriteAsync(headBytes, 0, headBytes.Length, ct);

        // 64 KiB 分块
        await using var fs = new FileStream(file.LocalPath, FileMode.Open, FileAccess.Read, FileShare.Read);
        var buf = new byte[64 * 1024];
        while (true)
        {
            var n = await fs.ReadAsync(buf, 0, buf.Length, ct);
            if (n == 0) break;
            await ssl.WriteAsync(buf, 0, n, ct);
        }
        await ssl.FlushAsync(ct);
    }

    /// <summary>
    /// RFC 5987 编码：用于 Content-Disposition: filename*=UTF-8''<encoded>
    /// 保护中文 / 特殊字符文件名。
    /// </summary>
    private static string Rfc5987Encode(string s)
    {
        var sb = new StringBuilder(s.Length * 3);
        foreach (var b in Encoding.UTF8.GetBytes(s))
        {
            if ((b >= 0x30 && b <= 0x39) ||      // 0-9
                (b >= 0x41 && b <= 0x5A) ||      // A-Z
                (b >= 0x61 && b <= 0x7A) ||      // a-z
                b == 0x2D || b == 0x2E ||        // -.
                b == 0x5F || b == 0x7E)          // _~
            {
                sb.Append((char)b);
            }
            else
            {
                sb.Append('%').Append(b.ToString("X2"));
            }
        }
        return sb.ToString();
    }

    // ─── WebSocket ─────────────────────────────────────────────────────

    private async Task UpgradeAndServeWebSocketAsync(SslStream ssl, Dictionary<string, string> headers, CancellationToken ct)
    {
        if (!headers.TryGetValue("Sec-WebSocket-Key", out var key) || string.IsNullOrEmpty(key))
        {
            await WriteJsonAsync(ssl, 400, "{\"ok\":false,\"error\":\"missing_ws_key\"}", ct);
            return;
        }
        var accept = ComputeWsAccept(key);
        var resp = $"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {accept}\r\n\r\n";
        var bytes = Encoding.ASCII.GetBytes(resp);
        await ssl.WriteAsync(bytes, 0, bytes.Length, ct);
        await ssl.FlushAsync(ct);

        var ws = WebSocket.CreateFromStream(ssl, isServer: true, subProtocol: null, keepAliveInterval: TimeSpan.FromSeconds(30));
        var wsId = Guid.NewGuid();
        _wsClients[wsId] = ws;

        // 初始 push 全状态快照
        try
        {
            var snapshot = _commands.Dispatch("{\"v\":1,\"id\":\"boot\",\"type\":\"get_state\"}");
            await SendTextAsync(ws, snapshot, ct);
        }
        catch { }

        var buf = new byte[64 * 1024];
        try
        {
            while (!ct.IsCancellationRequested && ws.State == WebSocketState.Open)
            {
                using var ms = new MemoryStream();
                WebSocketReceiveResult res;
                do
                {
                    res = await ws.ReceiveAsync(buf, ct);
                    if (res.MessageType == WebSocketMessageType.Close)
                    {
                        await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "bye", CancellationToken.None);
                        return;
                    }
                    ms.Write(buf, 0, res.Count);
                } while (!res.EndOfMessage);

                if (res.MessageType != WebSocketMessageType.Text) continue;
                var text = Encoding.UTF8.GetString(ms.ToArray());
                var reply = _commands.Dispatch(text);
                await SendTextAsync(ws, reply, ct);
            }
        }
        catch { }
        finally
        {
            // 断开时真正从集合移除（fix #79），避免死连接累积。
            _wsClients.TryRemove(wsId, out _);
            try { ws.Dispose(); } catch { }
        }
    }

    private async Task SendTextAsync(WebSocket ws, string text, CancellationToken ct)
    {
        var bytes = Encoding.UTF8.GetBytes(text);
        await ws.SendAsync(bytes, WebSocketMessageType.Text, endOfMessage: true, ct);
    }

    private void OnEngineEvent(EngineEvent ev)
    {
        var json = _commands.EncodeEvent(ev);
        var bytes = Encoding.UTF8.GetBytes(json);
        foreach (var kv in _wsClients)
        {
            var ws = kv.Value;
            if (ws.State != WebSocketState.Open)
            {
                _wsClients.TryRemove(kv.Key, out _);
                continue;
            }
            try { _ = ws.SendAsync(bytes, WebSocketMessageType.Text, true, CancellationToken.None); }
            catch { _wsClients.TryRemove(kv.Key, out _); }
        }
    }

    private static string ComputeWsAccept(string key)
    {
        const string magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
        var hash = SHA1.HashData(Encoding.ASCII.GetBytes(key.Trim() + magic));
        return Convert.ToBase64String(hash);
    }

    private static bool IsWebSocketUpgrade(Dictionary<string, string> headers)
    {
        return headers.TryGetValue("Upgrade", out var up)
               && string.Equals(up.Trim(), "websocket", StringComparison.OrdinalIgnoreCase);
    }

    // ─── HTTP/1.1 极简实现 ─────────────────────────────────────────────

    /// <summary>
    /// 只读起始行 + headers，返回 reader 供按需读 body（让调用方按鉴权状态决定限额，
    /// 避免在读 body 前就把未鉴权大 body 全收进内存）。
    /// </summary>
    private static async Task<(string? method, string path, Dictionary<string, string> headers, ByteLineReader? reader)>
        ReadHeadersAsync(Stream s, CancellationToken ct)
    {
        var reader = new ByteLineReader(s);
        var startLine = await reader.ReadLineAsync(ct);
        if (startLine is null) return (null, "", new(), null);
        var parts = startLine.Split(' ', 3);
        if (parts.Length < 2) return (null, "", new(), null);
        var method = parts[0];
        var path = parts[1];

        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        while (true)
        {
            var line = await reader.ReadLineAsync(ct);
            if (line is null) return (null, "", new(), null);
            if (line.Length == 0) break;
            var idx = line.IndexOf(':');
            if (idx <= 0) continue;
            headers[line.Substring(0, idx).Trim()] = line.Substring(idx + 1).Trim();
        }
        return (method, path, headers, reader);
    }

    private static async Task WriteResponseAsync(Stream s, int status, string reason,
        Dictionary<string, string> extraHeaders, byte[] body, CancellationToken ct)
    {
        var sb = new StringBuilder();
        sb.Append($"HTTP/1.1 {status} {reason}\r\n");
        if (!extraHeaders.ContainsKey("Content-Length")) extraHeaders["Content-Length"] = body.Length.ToString();
        if (!extraHeaders.ContainsKey("Connection")) extraHeaders["Connection"] = "close";
        foreach (var (k, v) in extraHeaders) sb.Append($"{k}: {v}\r\n");
        sb.Append("\r\n");
        var header = Encoding.ASCII.GetBytes(sb.ToString());
        await s.WriteAsync(header, 0, header.Length, ct);
        if (body.Length > 0) await s.WriteAsync(body, 0, body.Length, ct);
        await s.FlushAsync(ct);
    }

    private static Task WriteHtmlAsync(Stream s, string html, CancellationToken ct) =>
        WriteResponseAsync(s, 200, "OK",
            new Dictionary<string, string> { ["Content-Type"] = "text/html; charset=utf-8" },
            Encoding.UTF8.GetBytes(html), ct);

    private static Task WriteJsonAsync(Stream s, int status, string json, CancellationToken ct) =>
        WriteResponseAsync(s, status, status == 200 ? "OK" : "Error",
            new Dictionary<string, string> { ["Content-Type"] = "application/json; charset=utf-8" },
            Encoding.UTF8.GetBytes(json), ct);

    // ─── session / pairing ────────────────────────────────────────────

    /// 鉴权 token 来源（按优先级）：
    /// 1. URL query `?token=<sid>`（WS 连接 URL 用，cookie 在 wss upgrade 上不一定带）
    /// 2. Header `x-meshdrop-token`（multipart upload 等 fetch 调用用）
    /// 3. Cookie `meshdrop_session=<sid>`（与 Linux / Apple 对齐）
    /// 4. Cookie `meshdrop_sid=<sid>`（旧名，向后兼容）
    private static string ExtractSessionToken(string path, Dictionary<string, string> headers)
    {
        // query
        var q = path.IndexOf('?');
        if (q >= 0)
        {
            foreach (var kv in path[(q + 1)..].Split('&'))
            {
                var eq = kv.IndexOf('=');
                if (eq <= 0) continue;
                if (kv[..eq] == "token") return Uri.UnescapeDataString(kv[(eq + 1)..]);
            }
        }
        // header
        if (headers.TryGetValue("x-meshdrop-token", out var h) && !string.IsNullOrEmpty(h)) return h;
        // cookies
        if (headers.TryGetValue("Cookie", out var c))
        {
            foreach (var part in c.Split(';'))
            {
                var p = part.Trim();
                if (p.StartsWith("meshdrop_session=")) return p.Substring("meshdrop_session=".Length);
                if (p.StartsWith("meshdrop_sid=")) return p.Substring("meshdrop_sid=".Length);
            }
        }
        return "";
    }

    private bool IsSessionValid(string sid)
    {
        if (!_sessions.TryGetValue(sid, out var exp)) return false;
        if (exp <= DateTimeOffset.UtcNow) { _sessions.TryRemove(sid, out _); return false; }
        return true;
    }

    private static string NewSessionId()
    {
        Span<byte> buf = stackalloc byte[18];
        RandomNumberGenerator.Fill(buf);
        return Convert.ToBase64String(buf).Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }

    // ─── 配对码爆破防护（per-IP）────────────────────────────────────────

    private static string RemoteIp(TcpClient tcp)
    {
        try
        {
            if (tcp.Client.RemoteEndPoint is IPEndPoint ep) return ep.Address.ToString();
        }
        catch { }
        return "unknown";
    }

    private bool IsPairLockedOut(string ip)
    {
        if (!_pairFailures.TryGetValue(ip, out var rec)) return false;
        if (rec.fails < PairMaxFailures) return false;
        if (rec.until > DateTimeOffset.UtcNow) return true;
        // 锁定窗口已过：清零，给一次新的机会。
        _pairFailures.TryRemove(ip, out _);
        return false;
    }

    private void RecordPairFailure(string ip)
    {
        _pairFailures.AddOrUpdate(ip,
            _ => (1, DateTimeOffset.UtcNow.Add(PairLockout)),
            (_, old) =>
            {
                var fails = old.fails + 1;
                // 达阈值时刷新锁定截止时刻，形成持续退避。
                var until = fails >= PairMaxFailures ? DateTimeOffset.UtcNow.Add(PairLockout) : old.until;
                return (fails, until);
            });
    }

    private void ResetPairFailures(string ip) => _pairFailures.TryRemove(ip, out _);

    private static string ExtractAuthCode(byte[] body)
    {
        // 兼容 application/x-www-form-urlencoded 和 application/json
        var s = Encoding.UTF8.GetString(body).Trim();
        if (s.StartsWith("{"))
        {
            try
            {
                using var doc = System.Text.Json.JsonDocument.Parse(s);
                if (doc.RootElement.TryGetProperty("code", out var c)) return c.GetString() ?? "";
            }
            catch { }
        }
        // form url-encoded：code=ABCDEF
        foreach (var kv in s.Split('&'))
        {
            var idx = kv.IndexOf('=');
            if (idx <= 0) continue;
            var k = kv.Substring(0, idx);
            var v = kv.Substring(idx + 1);
            if (k == "code") return Uri.UnescapeDataString(v);
        }
        return "";
    }

    // ─── upload / fallback ────────────────────────────────────────────

    private static async Task<string> SaveUploadAsync(ByteLineReader reader, int contentLength, CancellationToken ct)
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MeshDrop", "uploads");
        Directory.CreateDirectory(dir);
        var path = Path.Combine(dir, Guid.NewGuid().ToString("N"));
        await using var fs = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
        await reader.CopyBodyToAsync(fs, contentLength, ct);
        return path;
    }

    private string FallbackHtml()
    {
        // 优先从 Assets\web-fallback\index.html 加载；不存在则内嵌兜底
        try
        {
            var asm = Assembly.GetExecutingAssembly();
            var asmDir = Path.GetDirectoryName(asm.Location);
            if (asmDir is not null)
            {
                var p = Path.Combine(asmDir, "Assets", "web-fallback", "index.html");
                if (File.Exists(p)) return File.ReadAllText(p);
            }
        }
        catch { }
        return EmbeddedFallbackHtml;
    }

    private const string EmbeddedFallbackHtml = """
<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8"/>
<title>MeshDrop · Web Gateway</title>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<style>
  body { background:#0a0a0a; color:#eaeaea; font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; margin:0; padding:48px; }
  .card { max-width:480px; margin:0 auto; padding:32px; border:1px solid #2a2a2a; border-radius:14px; background:#111; }
  h1 { margin:0 0 8px 0; font-size:20px; }
  p { opacity:.7; font-size:13px; line-height:1.6; }
  input[type=text] { width:100%; padding:12px; font-family:inherit; font-size:18px; letter-spacing:4px; text-transform:uppercase; background:#0a0a0a; color:#ddf94b; border:1px solid #2a2a2a; border-radius:8px; }
  button { margin-top:16px; padding:10px 16px; background:#ddf94b; color:#0a0a0a; border:0; border-radius:8px; font-weight:600; cursor:pointer; }
  .msg { margin-top:14px; min-height:1.4em; font-size:12px; }
  .ok { color:#9ee84a; }
  .err { color:#ff5a2c; }
</style>
</head>
<body>
<div class="card">
  <h1>MeshDrop · Web Gateway</h1>
  <p>请打开 Windows 上的 MeshDrop 应用，在 设置 · Web 访问 看到 6 位配对码。</p>
  <form id="f">
    <input id="code" type="text" maxlength="6" placeholder="ABCDEF" autocomplete="off" autofocus/>
    <button type="submit">连接 · CONNECT</button>
  </form>
  <div class="msg" id="msg"></div>
</div>
<script>
document.getElementById('f').addEventListener('submit', async (e) => {
  e.preventDefault();
  const code = document.getElementById('code').value.trim().toUpperCase();
  const msg = document.getElementById('msg');
  msg.textContent = '验证中…';
  msg.className = 'msg';
  try {
    const r = await fetch('/api/v1/pair', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code }),
    });
    const j = await r.json();
    if (j.ok) { msg.textContent = '已通过 · 正在连接 WebSocket…'; msg.className = 'msg ok'; connect(); }
    else { msg.textContent = '配对码错误'; msg.className = 'msg err'; }
  } catch (err) { msg.textContent = '请求失败: ' + err.message; msg.className = 'msg err'; }
});
function connect() {
  const ws = new WebSocket((location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + '/api/v1/control');
  ws.onopen = () => console.log('[meshdrop] ws open');
  ws.onmessage = (ev) => console.log('[meshdrop] evt', ev.data);
  ws.onclose = () => console.log('[meshdrop] ws closed');
}
</script>
</body>
</html>
""";

    // ─── helpers ────────────────────────────────────────────────────────

    private sealed class ByteLineReader
    {
        private readonly Stream _s;
        private readonly byte[] _buf = new byte[1];
        public ByteLineReader(Stream s) { _s = s; }

        public async Task<string?> ReadLineAsync(CancellationToken ct)
        {
            var sb = new StringBuilder();
            while (true)
            {
                int n;
                try { n = await _s.ReadAsync(_buf, 0, 1, ct); } catch { return null; }
                if (n <= 0) return sb.Length == 0 ? null : sb.ToString();
                var c = (char)_buf[0];
                if (c == '\r') continue;
                if (c == '\n') return sb.ToString();
                sb.Append(c);
                if (sb.Length > 8192) return null; // 防御
            }
        }

        public async Task<byte[]> ReadBytesAsync(int total, CancellationToken ct)
        {
            if (total <= 0) return Array.Empty<byte>();
            var data = new byte[total];
            var read = 0;
            while (read < total)
            {
                var n = await _s.ReadAsync(data, read, total - read, ct);
                if (n <= 0) break;
                read += n;
            }
            return read == total ? data : data.AsSpan(0, read).ToArray();
        }

        /// <summary>把声明长度的 body 分块拷到目标流，不在内存里整段缓存。</summary>
        public async Task CopyBodyToAsync(Stream dest, int contentLength, CancellationToken ct)
        {
            var remaining = contentLength;
            var buf = new byte[64 * 1024];
            while (remaining > 0)
            {
                var toRead = Math.Min(buf.Length, remaining);
                var n = await _s.ReadAsync(buf, 0, toRead, ct);
                if (n <= 0) break;
                await dest.WriteAsync(buf, 0, n, ct);
                remaining -= n;
            }
        }
    }
}
