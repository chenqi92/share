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
///   - POST /api/v1/auth        → 验 pairing code，下发 session cookie
///   - WS  /api/v1/control      → 双向命令 / 事件通道
///   - POST /api/v1/upload      → multipart 暂存文件，返 uploadToken
///   - GET  /api/v1/download/{} → 接受 offer 后下载流（v0.1：本地保存路径）
///
/// 用 TcpListener + SslStream + System.Net.WebSockets 手搭，
/// 不引第三方 web framework。
/// </summary>
public sealed class WebGatewayHost
{
    public const ushort DefaultPort = 7384;

    private readonly ShareEngine _engine;
    private readonly GatewayCommands _commands;
    private readonly PairingCodeStore _pairingStore = new();
    private readonly ConcurrentDictionary<string, DateTimeOffset> _sessions = new();
    private readonly ConcurrentBag<WebSocket> _wsClients = new();
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
        foreach (var ws in _wsClients)
        {
            try { ws.Abort(); } catch { }
            try { ws.Dispose(); } catch { }
        }
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
            await ssl.AuthenticateAsServerAsync(_cert!, clientCertificateRequired: false,
                                                System.Security.Authentication.SslProtocols.Tls12 | System.Security.Authentication.SslProtocols.Tls13,
                                                checkCertificateRevocation: false);

            var (method, path, headers, body) = await ReadRequestAsync(ssl, ct);
            if (method is null) return;

            var sessionId = ReadSessionCookie(headers);
            var isAuth = !string.IsNullOrEmpty(sessionId) && IsSessionValid(sessionId);

            // 路由
            if (method == "GET" && path == "/")
            {
                await WriteHtmlAsync(ssl, FallbackHtml(), ct);
                return;
            }
            if (method == "POST" && path == "/api/v1/auth")
            {
                var code = ExtractAuthCode(body);
                if (_pairingStore.Verify(code))
                {
                    var sid = NewSessionId();
                    _sessions[sid] = DateTimeOffset.UtcNow.AddHours(24);
                    await WriteResponseAsync(ssl, 200, "OK",
                        new Dictionary<string, string>
                        {
                            ["Content-Type"] = "application/json; charset=utf-8",
                            ["Set-Cookie"] = $"meshdrop_sid={sid}; Path=/; HttpOnly; Secure; Max-Age=86400; SameSite=Strict",
                        },
                        Encoding.UTF8.GetBytes("{\"ok\":true}"), ct);
                }
                else
                {
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
                // v0.1 占位：直接把 body 当文件流写到 LocalAppData/uploads/<guid>，返回 fileRef
                var tokenPath = await SaveUploadAsync(body);
                await WriteJsonAsync(ssl, 200,
                    $"{{\"ok\":true,\"uploadToken\":\"{tokenPath.Replace("\\", "\\\\")}\"}}", ct);
                return;
            }
            if (method == "GET" && path.StartsWith("/api/v1/download/"))
            {
                await WriteJsonAsync(ssl, 501, "{\"ok\":false,\"error\":\"download_not_implemented\"}", ct);
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
        _wsClients.Add(ws);

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
        var json = GatewayCommands.EncodeEvent(ev);
        var dead = new List<WebSocket>();
        foreach (var ws in _wsClients)
        {
            if (ws.State != WebSocketState.Open) { dead.Add(ws); continue; }
            try { _ = ws.SendAsync(Encoding.UTF8.GetBytes(json), WebSocketMessageType.Text, true, CancellationToken.None); }
            catch { dead.Add(ws); }
        }
        // 清理 dead — ConcurrentBag 没有 Remove，跳过；下次 Send 自然 skip
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

    private static async Task<(string? method, string path, Dictionary<string, string> headers, byte[] body)>
        ReadRequestAsync(Stream s, CancellationToken ct)
    {
        var reader = new ByteLineReader(s);
        var startLine = await reader.ReadLineAsync(ct);
        if (startLine is null) return (null, "", new(), Array.Empty<byte>());
        var parts = startLine.Split(' ', 3);
        if (parts.Length < 2) return (null, "", new(), Array.Empty<byte>());
        var method = parts[0];
        var path = parts[1];

        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        while (true)
        {
            var line = await reader.ReadLineAsync(ct);
            if (line is null) return (null, "", new(), Array.Empty<byte>());
            if (line.Length == 0) break;
            var idx = line.IndexOf(':');
            if (idx <= 0) continue;
            headers[line.Substring(0, idx).Trim()] = line.Substring(idx + 1).Trim();
        }

        var bodyLen = 0;
        if (headers.TryGetValue("Content-Length", out var clStr)) int.TryParse(clStr, out bodyLen);
        var body = bodyLen > 0 ? await reader.ReadBytesAsync(bodyLen, ct) : Array.Empty<byte>();
        return (method, path, headers, body);
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

    private static string ReadSessionCookie(Dictionary<string, string> headers)
    {
        if (!headers.TryGetValue("Cookie", out var c)) return "";
        foreach (var part in c.Split(';'))
        {
            var p = part.Trim();
            if (p.StartsWith("meshdrop_sid=")) return p.Substring("meshdrop_sid=".Length);
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

    private static async Task<string> SaveUploadAsync(byte[] body)
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MeshDrop", "uploads");
        Directory.CreateDirectory(dir);
        var path = Path.Combine(dir, Guid.NewGuid().ToString("N"));
        await File.WriteAllBytesAsync(path, body);
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
    const r = await fetch('/api/v1/auth', {
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
    }
}
