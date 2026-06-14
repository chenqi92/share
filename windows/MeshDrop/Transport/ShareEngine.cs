using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Discovery;
using MeshDrop.Models;
using MeshDrop.Protocol;
using Microsoft.UI.Dispatching;

namespace MeshDrop.Transport;

/// <summary>
/// 别名：本仓库统一暴露 <see cref="ShareEngine"/>（与 mac / android / linux 同名），
/// 同时按 prompt 文档约定提供 <c>MeshDropEngine.Instance</c>。两者指向同一单例。
/// </summary>
public static class MeshDropEngine
{
    public static ShareEngine Instance => ShareEngine.Shared;
}

/// <summary>
/// 顶层引擎：进程单例。持有 Identity、Discovery、TrustStore，对外暴露设备
/// 列表、历史、待审配对/文件 offer。整链路对齐 Apple/Android。
/// </summary>
public sealed partial class ShareEngine : ObservableObject
{
    private const int ChunkSize = 256 * 1024;
    private const long ResumePersistInterval = 4L * 1024L * 1024L;
    private static readonly Lazy<ShareEngine> s_lazy = new(() => new ShareEngine());
    public static ShareEngine Shared => s_lazy.Value;

    private readonly DispatcherQueue _ui;
    private readonly TrustStore _trustStore = new();
    private readonly ResumeStore _resumeStore = new();
    private readonly MdnsDiscovery _discovery;
    private readonly ConcurrentDictionary<Guid, ConnectionContext> _contexts = new();

    // 协议不变量（security.md §重放）：TEXT / FILE_OFFER 带 UUID id，接收侧按
    // (peerFp, messageId) 做 5 分钟窗口去重，命中即丢弃，避免断连重发 / 恶意重放
    // 导致同一消息重复入库或重复弹 offer。仅在 UI 线程访问。
    private static readonly TimeSpan ReplayWindow = TimeSpan.FromMinutes(5);
    private readonly Dictionary<string, DateTime> _seenMessages = new(StringComparer.Ordinal);

    private TcpListener? _listener;
    private CancellationTokenSource? _cts;
    private ushort _listenPort;
    private DispatcherQueueTimer? _throughputTimer;
    private const int ThroughputBuckets = 14;
    private readonly List<double> _tpUp = new();
    private readonly List<double> _tpDown = new();

    public Identity Identity { get; }
    public string? Model { get; }

    // 可观察状态
    [ObservableProperty] private string _displayName;
    [ObservableProperty] private bool _isStarting;
    [ObservableProperty] private bool _isRunning;
    [ObservableProperty] private string? _lastError;
    [ObservableProperty] private string _localIp = "—";

    /// <summary>会话级吞吐时间序列（每秒一桶，bytes/sec，最新在后，上限 14）。传输页速度柱状图用。</summary>
    [ObservableProperty] private IReadOnlyList<double> _throughputUp = Array.Empty<double>();
    [ObservableProperty] private IReadOnlyList<double> _throughputDown = Array.Empty<double>();

    /// <summary>设置：收到来自已信任设备的文件 offer 时自动接受（持久化到 LocalAppData）。</summary>
    [ObservableProperty] private bool _autoAcceptFromTrusted;

    public ObservableCollection<Device> Devices { get; } = new();
    public ObservableCollection<HistoryItem> History { get; } = new();
    public ObservableCollection<PendingPairing> PendingPairings { get; } = new();
    public ObservableCollection<PendingFileOffer> PendingFileOffers { get; } = new();
    public ObservableCollection<TrustRecord> Trusted { get; } = new();

    /// <summary>收到的剪贴板推送（最新在前，上限 50）。见 protocol/messages.md §0x11。</summary>
    public ObservableCollection<ClipboardEntry> ClipboardInbox { get; } = new();

    /// <summary>
    /// 进行中传输的实时速率 + ETA。Key 为 history.id；进入 terminal 状态时被
    /// UpdateHistory 移除。WinUI 列表行用 TransferMetricsChanged 事件刷新。
    /// </summary>
    public Dictionary<Guid, TransferMetrics> TransferMetrics { get; } = new();
    public event Action<Guid, TransferMetrics?>? TransferMetricsChanged;

    /// <summary>跨端通用事件：设备加入 / 离开 / 待审 / 进度 / 传输完成。Gateway 订阅。</summary>
    public event Action<EngineEvent>? Event;

    public Device SelfDevice => new(
        Identity.Id, DisplayName, DeviceOS.Windows, Model, Identity.Fingerprint,
        _listenPort, 1, _localIp);

    private ShareEngine()
    {
        _ui = DispatcherQueue.GetForCurrentThread()
              ?? throw new InvalidOperationException("ShareEngine must be created on UI thread");
        Identity = Identity.LoadOrCreate();
        _displayName = Environment.MachineName;
        Model = "Windows PC";

        _discovery = new MdnsDiscovery(Identity, DisplayName, Model);
        _discovery.DevicesChanged += OnDevicesChanged;
        _autoAcceptFromTrusted = LoadAutoAccept();

        foreach (var r in _trustStore.Snapshot()) Trusted.Add(r);
    }

    partial void OnAutoAcceptFromTrustedChanged(bool value) => SaveAutoAccept(value);

    private static string AutoAcceptPath() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MeshDrop", "auto_accept");

    private static bool LoadAutoAccept()
    {
        try { return File.Exists(AutoAcceptPath()) && File.ReadAllText(AutoAcceptPath()).Trim() == "1"; }
        catch { return false; }
    }

    private static void SaveAutoAccept(bool value)
    {
        try
        {
            var p = AutoAcceptPath();
            Directory.CreateDirectory(Path.GetDirectoryName(p)!);
            File.WriteAllText(p, value ? "1" : "0");
        }
        catch { }
    }

    public void SetDisplayName(string name)
    {
        var trimmed = (name ?? string.Empty).Trim();
        if (string.IsNullOrEmpty(trimmed) || trimmed == DisplayName) return;
        DisplayName = trimmed;
        // mdns advertise 已经起来时，重启发现广告以新名字 announce
        if (IsRunning && _listenPort > 0)
        {
            try
            {
                _discovery.Stop();
                _discovery.Start(_listenPort, DisplayName);
            }
            catch (Exception ex) { LastError = ex.Message; }
        }
        OnPropertyChanged(nameof(SelfDevice));
    }

    // ─── 生命周期 ───────────────────────────────────────────────────────

    public async Task StartAsync()
    {
        if (_listener is not null) return;
        IsStarting = true;
        LastError = null;

        try
        {
            _listener = new TcpListener(IPAddress.Any, 0);
            _listener.Start();
            var port = (ushort)((IPEndPoint)_listener.LocalEndpoint).Port;
            _listenPort = port;
            LocalIp = ResolveLocalIp();

            _cts = new CancellationTokenSource();
            _discovery.Start(port, DisplayName);

            _ = AcceptLoopAsync(_cts.Token);

            // 每秒采样会话吞吐，喂给传输页速度柱状图（UI 线程 timer，安全改 ObservableProperty）。
            _throughputTimer = _ui.CreateTimer();
            _throughputTimer.Interval = TimeSpan.FromSeconds(1);
            _throughputTimer.Tick += (_, _) => SampleThroughput();
            _throughputTimer.Start();

            IsRunning = true;
        }
        catch (Exception ex)
        {
            LastError = ex.Message;
            _listener?.Stop();
            _listener = null;
        }
        finally
        {
            IsStarting = false;
            OnPropertyChanged(nameof(SelfDevice));
        }
        await Task.CompletedTask;
    }

    public Task StopAsync()
    {
        Stop();
        return Task.CompletedTask;
    }

    public void Stop()
    {
        _cts?.Cancel();
        _listener?.Stop();
        _listener = null;
        _discovery.Stop();
        _throughputTimer?.Stop();
        _throughputTimer = null;
        _tpUp.Clear();
        _tpDown.Clear();
        ThroughputUp = Array.Empty<double>();
        ThroughputDown = Array.Empty<double>();
        foreach (var ctx in _contexts.Values) ctx.Connection.Close();
        _contexts.Clear();
        IsRunning = false;
        OnPropertyChanged(nameof(SelfDevice));
    }

    private static string ResolveLocalIp()
    {
        try
        {
            foreach (var nic in System.Net.NetworkInformation.NetworkInterface.GetAllNetworkInterfaces())
            {
                if (nic.OperationalStatus != System.Net.NetworkInformation.OperationalStatus.Up) continue;
                if (nic.NetworkInterfaceType == System.Net.NetworkInformation.NetworkInterfaceType.Loopback) continue;
                foreach (var addr in nic.GetIPProperties().UnicastAddresses)
                {
                    if (addr.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                    var s = addr.Address.ToString();
                    if (s.StartsWith("169.254.")) continue;
                    return s;
                }
            }
        }
        catch { }
        return "127.0.0.1";
    }

    // ─── 历史 ────────────────────────────────────────────────────────────

    public void RemoveHistoryItem(Guid id)
    {
        var item = History.FirstOrDefault(h => h.Id == id);
        if (item is not null) History.Remove(item);
    }

    public void ClearHistory() => History.Clear();

    // ─── 出方：文本 ──────────────────────────────────────────────────────

    public void SendText(Device device, string content)
    {
        var item = HistoryItem.Create(device, TransferDirection.Outgoing,
            new HistoryKind.Text(content), new TransferStatus.Pending());
        History.Insert(0, item);
        RaiseEvent(new EngineEvent.HistoryAdded(item));

        if (string.IsNullOrEmpty(device.Host))
        {
            UpdateHistory(item.Id, new TransferStatus.Failed("无可用 IP"));
            return;
        }

        var conn = Connection.ForOutgoing(device.Host, device.Port);
        var ctx = new ConnectionContext(conn,
            new ConnectionContext.RoleClient(device, new ConnectionContext.PayloadText(content)),
            ConnectionContext.StateAwaitingHelloAck)
        { HistoryId = item.Id };
        _contexts[ctx.Id] = ctx;
        StartConnection(ctx);
    }

    // ─── 出方：剪贴板 ────────────────────────────────────────────────────

    /// <summary>
    /// 显式剪贴板推送（用户主动触发，非后台静默同步）。复用与 TEXT 相同的连接
    /// 生命周期：建出方连接 → HELLO/ACK → CLIPBOARD → 关。不写入文件历史。
    /// Kind ∈ {text|link|code}，由调用方按内容判定（见 <see cref="ClipKind"/>）。
    /// </summary>
    public void PushClipboard(Device device, string content, string kind)
    {
        if (string.IsNullOrEmpty(content) || string.IsNullOrEmpty(device.Host)) return;
        var conn = Connection.ForOutgoing(device.Host, device.Port);
        var ctx = new ConnectionContext(conn,
            new ConnectionContext.RoleClient(device, new ConnectionContext.PayloadClipboard(content, kind)),
            ConnectionContext.StateAwaitingHelloAck);
        _contexts[ctx.Id] = ctx;
        StartConnection(ctx);
    }

    /// <summary>
    /// 按内容粗判剪贴板 kind（与 Apple / Android / Web 端同口径）：
    /// http(s):// 开头且无空白 → link；含换行且出现代码特征字符 → code；否则 text。
    /// </summary>
    public static string ClipKind(string content)
    {
        var t = (content ?? string.Empty).Trim();
        if ((t.StartsWith("http://", StringComparison.Ordinal) || t.StartsWith("https://", StringComparison.Ordinal))
            && !t.Any(char.IsWhiteSpace))
            return "link";
        if (t.Contains('\n') && t.Any(c => "{};=<>/".Contains(c)))
            return "code";
        return "text";
    }

    // ─── 出方：文件 ──────────────────────────────────────────────────────

    public void SendFile(Device device, string sourcePath)
    {
        var info = new FileInfo(sourcePath);
        var item = HistoryItem.Create(device, TransferDirection.Outgoing,
            new HistoryKind.File(info.Name, info.Length, sourcePath),
            new TransferStatus.Pending());
        History.Insert(0, item);
        RaiseEvent(new EngineEvent.HistoryAdded(item));

        if (string.IsNullOrEmpty(device.Host))
        {
            UpdateHistory(item.Id, new TransferStatus.Failed("无可用 IP"));
            return;
        }

        // 后台算 sha256，再发起连接
        _ = Task.Run(async () =>
        {
            string sha;
            try { sha = await ComputeSha256Async(sourcePath); }
            catch (Exception ex)
            {
                _ui.TryEnqueue(() => UpdateHistory(item.Id, new TransferStatus.Failed(ex.Message)));
                return;
            }

            _ui.TryEnqueue(() =>
            {
                var conn = Connection.ForOutgoing(device.Host!, device.Port);
                var payload = new ConnectionContext.PayloadFile(sourcePath, info.Length, sha, info.Name);
                var ctx = new ConnectionContext(conn,
                    new ConnectionContext.RoleClient(device, payload),
                    ConnectionContext.StateAwaitingHelloAck)
                {
                    HistoryId = item.Id,
                    TransferId = Guid.NewGuid(),
                    FileSize = info.Length,
                };
                _contexts[ctx.Id] = ctx;
                UpdateHistory(item.Id, new TransferStatus.WaitingApproval());
                StartConnection(ctx);
            });
        });
    }

    // ─── 决定 ────────────────────────────────────────────────────────────

    public void RespondToPairing(Guid requestId, PairingDecision decision)
    {
        var req = PendingPairings.FirstOrDefault(p => p.Id == requestId);
        if (req is null) return;
        PendingPairings.Remove(req);

        var entry = _contexts.FirstOrDefault(kv =>
            kv.Value.State == ConnectionContext.StateAwaitingPairApproval
            && kv.Value.PendingPairingId == requestId);
        if (entry.Value is null) return;
        var ctx = entry.Value;

        switch (decision)
        {
            case PairingDecision.Reject:
                _ = CloseContextAsync(ctx.Id, null);
                break;
            case PairingDecision.AllowOnce:
                _ = SendAckAndReadyAsync(ctx, req.Peer);
                break;
            case PairingDecision.Trust:
                _trustStore.Trust(req.Peer.Fingerprint, req.Peer.Name);
                RefreshTrusted();
                _ = SendAckAndReadyAsync(ctx, req.Peer);
                break;
        }
    }

    /// <summary>
    /// 撤销已信任设备（TrustPage「撤销信任」按钮 / Settings）。fingerprint 为 32 位
    /// 小写 hex（指纹不变量）。撤销后下次该设备连接需重新走 TOFU 双向确认。
    /// </summary>
    public void RevokeTrust(string fingerprint)
    {
        if (string.IsNullOrEmpty(fingerprint)) return;
        _trustStore.Revoke(fingerprint);
        RefreshTrusted();
    }

    public void RespondToFileOffer(Guid offerId, bool accept)
    {
        var offer = PendingFileOffers.FirstOrDefault(o => o.Id == offerId);
        if (offer is null) return;
        PendingFileOffers.Remove(offer);

        var ctx = _contexts.Values.FirstOrDefault(c => c.PendingOfferId == offerId);
        if (ctx is null) return;

        if (!accept)
        {
            _ = Task.Run(async () =>
            {
                try
                {
                    var body = MessageCodec.Encode(new FileRejectMessage(offer.Id.ToString(), 0, "user_declined"));
                    await ctx.Connection.SendAsync(MessageType.FILE_REJECT, body);
                }
                catch { }
                await CloseContextAsync(ctx.Id, null);
            });
            return;
        }

        // 接受
        try
        {
            var dir = DefaultSaveDir(offer.Peer);
            Directory.CreateDirectory(dir);
            var path = UniqueFilePath(dir, offer.FileName);
            var stream = new FileStream(path, FileMode.Create, FileAccess.Write, FileShare.None);
            ctx.OutputStream = stream;
            ctx.SavedPath = path;
            ctx.FileSize = offer.FileSize;
            ctx.ReceivedBytes = 0;
            ctx.LastPersistedBytes = 0;
            ctx.ExpectedSha256 = offer.Sha256;
            ctx.TransferId = offer.Id;
            ctx.PendingOfferId = null;
            ctx.State = ConnectionContext.StateReceivingFile;

            var item = HistoryItem.Create(offer.Peer, TransferDirection.Incoming,
                new HistoryKind.File(offer.FileName, offer.FileSize, path),
                new TransferStatus.Transferring(0, offer.FileSize));
            History.Insert(0, item);
            RaiseEvent(new EngineEvent.HistoryAdded(item));
            ctx.HistoryId = item.Id;

            _ = Task.Run(async () =>
            {
                var body = MessageCodec.Encode(new FileAcceptMessage(offer.Id.ToString(), 0, 0));
                try { await ctx.Connection.SendAsync(MessageType.FILE_ACCEPT, body); }
                catch (Exception ex) { await CloseContextAsync(ctx.Id, ex); }
            });
        }
        catch (Exception ex)
        {
            _ = CloseContextAsync(ctx.Id, ex);
        }
    }

    /// <summary>
    /// 主动取消进行中的传输（发送/接收都能调）。查到对应 ctx 后：接收态先关
    /// stream 删半成品；双向发 FILE_CANCEL（whole transfer, index=null, reason=user_canceled）；
    /// 关 ctx，标 history Canceled。
    /// </summary>
    public void CancelTransfer(Guid historyId)
    {
        var ctx = _contexts.Values.FirstOrDefault(c => c.HistoryId == historyId);
        if (ctx is null) return;
        var transferId = ctx.TransferId ?? historyId;
        _ = Task.Run(async () =>
        {
            if (ctx.State == ConnectionContext.StateReceivingFile)
            {
                try { ctx.OutputStream?.Dispose(); } catch { }
                ctx.OutputStream = null;
                ClearResumeRecord(ctx);
                if (ctx.SavedPath is { } path)
                {
                    try { if (File.Exists(path)) File.Delete(path); } catch { }
                }
            }
            try
            {
                var body = MessageCodec.Encode(new FileCancelMessage(transferId.ToString(), null, "user_canceled"));
                await ctx.Connection.SendAsync(MessageType.FILE_CANCEL, body);
            }
            catch { }
            _ui.TryEnqueue(() => UpdateHistory(historyId, new TransferStatus.Canceled()));
            await CloseContextAsync(ctx.Id, null);
        });
    }

    /// <summary>
    /// 重发失败/取消的 outgoing 文件项。保留旧 history，新建一条发送记录走完整文件流程。
    /// </summary>
    public bool RetryTransfer(Guid historyId)
    {
        var item = History.FirstOrDefault(h => h.Id == historyId);
        if (item is null || item.Direction != TransferDirection.Outgoing)
            return false;
        if (item.Kind is not HistoryKind.File { LocalPath: { Length: > 0 } path })
            return false;
        if (!File.Exists(path))
            return false;

        SendFile(item.Peer, path);
        return true;
    }

    // ─── 入站连接 + 启动 ────────────────────────────────────────────────

    private async Task AcceptLoopAsync(CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested && _listener is not null)
            {
                var client = await _listener.AcceptTcpClientAsync(ct);
                _ = AcceptIncomingAsync(client);
            }
        }
        catch (OperationCanceledException) { }
        catch (ObjectDisposedException) { }
    }

    private Task AcceptIncomingAsync(TcpClient client)
    {
        var conn = Connection.ForIncoming(client);
        var ctx = new ConnectionContext(conn, ConnectionContext.RoleServerSingleton,
            ConnectionContext.StateAwaitingHello);
        _contexts[ctx.Id] = ctx;
        var ctxId = ctx.Id;
        conn.Start(
            onReady: () => Task.CompletedTask,
            onMessage: (t, b) => HandleMessageAsync(ctxId, t, b),
            onClose: ex => CloseContextAsync(ctxId, ex));
        return Task.CompletedTask;
    }

    private void StartConnection(ConnectionContext ctx)
    {
        var ctxId = ctx.Id;
        ctx.Connection.Start(
            onReady: () => SendInitialHelloAsync(ctxId),
            onMessage: (t, b) => HandleMessageAsync(ctxId, t, b),
            onClose: ex => CloseContextAsync(ctxId, ex));
    }

    // ─── 路由 ────────────────────────────────────────────────────────────

    private async Task HandleMessageAsync(Guid ctxId, byte type, byte[] body)
    {
        if (!_contexts.TryGetValue(ctxId, out var ctx)) return;
        var state = ctx.State;

        if (state == ConnectionContext.StateAwaitingHello && type == MessageType.HELLO)
        { await ServerReceivedHelloAsync(ctx, body); return; }

        if (state == ConnectionContext.StateAwaitingHelloAck && type == MessageType.HELLO_ACK)
        { await ClientReceivedAckAsync(ctx, body); return; }

        if (state == ConnectionContext.StateAwaitingFileAccept && type == MessageType.FILE_ACCEPT)
        { await ClientStartSendingAsync(ctx, body); return; }

        if (state == ConnectionContext.StateAwaitingFileAccept && type == MessageType.FILE_REJECT)
        {
            string reason = "rejected";
            try { reason = MessageCodec.Decode<FileRejectMessage>(body).Reason; } catch { }
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed($"对方拒收: {reason}")); });
            await CloseContextAsync(ctxId, null);
            return;
        }

        if (state == ConnectionContext.StateSendingFile && type == MessageType.FILE_COMPLETE)
        {
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Completed()); });
            await CloseContextAsync(ctxId, null);
            return;
        }

        if (state == ConnectionContext.StateReady && type == MessageType.TEXT)
        { HandleReceivedText(ctx, body); return; }

        if (state == ConnectionContext.StateReady && type == MessageType.CLIPBOARD)
        { HandleReceivedClipboard(ctx, body); return; }

        if (state == ConnectionContext.StateReady && type == MessageType.FILE_OFFER)
        { HandleReceivedFileOffer(ctx, body); return; }

        if (state == ConnectionContext.StateReceivingFile && type == MessageType.FILE_CHUNK)
        { await HandleReceivedChunkAsync(ctx, body); return; }

        if (type == MessageType.PING)
        { try { await ctx.Connection.SendAsync(MessageType.PONG, Encoding.UTF8.GetBytes("{}")); } catch { } return; }

        if (type == MessageType.PONG) return;

        if (type == MessageType.FILE_CANCEL)
        {
            // 对端取消传输：接收侧关 stream + 删半成品文件，避免落盘出现 0 字节 / 半截文件
            if (state == ConnectionContext.StateReceivingFile)
            {
                try { ctx.OutputStream?.Dispose(); } catch { }
                ctx.OutputStream = null;
                ClearResumeRecord(ctx);
                if (ctx.SavedPath is { } path)
                {
                    try { if (File.Exists(path)) File.Delete(path); } catch { }
                }
            }
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Canceled()); });
            await CloseContextAsync(ctxId, null);
            return;
        }

        await CloseContextAsync(ctxId, null);
    }

    // ─── HELLO 握手 ─────────────────────────────────────────────────────

    private async Task SendInitialHelloAsync(Guid ctxId)
    {
        if (!_contexts.TryGetValue(ctxId, out var ctx)) return;
        var hello = new HelloMessage(Identity.Id, DisplayName, "windows", Identity.Fingerprint, new() { 1 }, Model);
        try { await ctx.Connection.SendAsync(MessageType.HELLO, MessageCodec.Encode(hello)); }
        catch (Exception ex) { await CloseContextAsync(ctxId, ex); }
    }

    private async Task ServerReceivedHelloAsync(ConnectionContext ctx, byte[] body)
    {
        HelloMessage? hello = null;
        try { hello = MessageCodec.Decode<HelloMessage>(body); } catch { }
        if (hello is null) { await CloseContextAsync(ctx.Id, null); return; }
        if (!hello.ProtocolVersions.Contains((byte)1)) { await CloseContextAsync(ctx.Id, null); return; }

        var os = DeviceOSExtensions.Parse(hello.Os) ?? DeviceOS.Linux;
        var peer = new Device(hello.Id, hello.Name, os, hello.Model, hello.Fp, 0, 1, null);
        ctx.Peer = peer;

        if (_trustStore.IsTrusted(hello.Fp))
        {
            _trustStore.Touch(hello.Fp);
            _ui.TryEnqueue(RefreshTrusted);
            await SendAckAndReadyAsync(ctx, peer);
        }
        else
        {
            var req = PendingPairing.Create(peer);
            ctx.State = ConnectionContext.StateAwaitingPairApproval;
            ctx.PendingPairingId = req.Id;
            _ui.TryEnqueue(() =>
            {
                PendingPairings.Add(req);
                RaiseEvent(new EngineEvent.PairingPending(req));
            });
        }
    }

    private async Task SendAckAndReadyAsync(ConnectionContext ctx, Device peer)
    {
        var ack = new HelloAckMessage(Identity.Id, DisplayName, "windows",
            Identity.Fingerprint, new() { 1 }, 1, Model);
        try
        {
            await ctx.Connection.SendAsync(MessageType.HELLO_ACK, MessageCodec.Encode(ack));
            ctx.State = ConnectionContext.StateReady;
            ctx.Peer = peer;
        }
        catch (Exception ex) { await CloseContextAsync(ctx.Id, ex); }
    }

    private async Task ClientReceivedAckAsync(ConnectionContext ctx, byte[] body)
    {
        HelloAckMessage? ack = null;
        try { ack = MessageCodec.Decode<HelloAckMessage>(body); } catch { }
        if (ack is null) { await CloseContextAsync(ctx.Id, null); return; }
        if (ctx.Role is not ConnectionContext.RoleClient role) { await CloseContextAsync(ctx.Id, null); return; }
        if (ack.Fp != role.Target.Fingerprint) { await CloseContextAsync(ctx.Id, null); return; }
        ctx.Peer = role.Target;

        switch (role.Payload)
        {
            case ConnectionContext.PayloadText t:
                {
                    var msg = new TextMessage(Guid.NewGuid().ToString(), t.Content,
                        DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                    try
                    {
                        await ctx.Connection.SendAsync(MessageType.TEXT, MessageCodec.Encode(msg));
                        _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Completed()); });
                        await Task.Delay(200);
                        await CloseContextAsync(ctx.Id, null);
                    }
                    catch (Exception ex)
                    {
                        _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed(ex.Message)); });
                        await CloseContextAsync(ctx.Id, ex);
                    }
                    break;
                }
            case ConnectionContext.PayloadClipboard c:
                {
                    var msg = new ClipboardMessage(Guid.NewGuid().ToString(), c.Content, c.Kind,
                        DateTimeOffset.UtcNow.ToUnixTimeSeconds());
                    try
                    {
                        await ctx.Connection.SendAsync(MessageType.CLIPBOARD, MessageCodec.Encode(msg));
                        await Task.Delay(200);
                        await CloseContextAsync(ctx.Id, null);
                    }
                    catch (Exception ex)
                    {
                        await CloseContextAsync(ctx.Id, ex);
                    }
                    break;
                }
            case ConnectionContext.PayloadFile f:
                {
                    var tid = ctx.TransferId ?? Guid.NewGuid();
                    ctx.TransferId = tid;
                    var offer = new FileOfferMessage(tid.ToString(),
                        new() { new FileMeta(0, f.FileName, f.FileSize, f.Sha256) });
                    try
                    {
                        await ctx.Connection.SendAsync(MessageType.FILE_OFFER, MessageCodec.Encode(offer));
                        ctx.State = ConnectionContext.StateAwaitingFileAccept;
                    }
                    catch (Exception ex)
                    {
                        _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed(ex.Message)); });
                        await CloseContextAsync(ctx.Id, ex);
                    }
                    break;
                }
        }
    }

    // ─── 文件发送 ────────────────────────────────────────────────────────

    private async Task ClientStartSendingAsync(ConnectionContext ctx, byte[] acceptBody)
    {
        if (ctx.Role is not ConnectionContext.RoleClient role) return;
        if (role.Payload is not ConnectionContext.PayloadFile f) return;
        FileAcceptMessage accept;
        try { accept = MessageCodec.Decode<FileAcceptMessage>(acceptBody); }
        catch (Exception ex)
        {
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed($"FILE_ACCEPT 解码失败: {ex.Message}")); });
            await CloseContextAsync(ctx.Id, ex);
            return;
        }
        if (accept.Index != 0
            || ctx.TransferId is not { } transferId
            || !Guid.TryParse(accept.TransferId, out var acceptTransferId)
            || acceptTransferId != transferId)
        {
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed("FILE_ACCEPT transfer_id 不匹配")); });
            await CloseContextAsync(ctx.Id, null);
            return;
        }
        var resumeOffset = Math.Clamp(accept.ResumeOffset, 0, f.FileSize);
        try
        {
            ctx.InputStream = new FileStream(f.SourcePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            if (resumeOffset > 0)
                ctx.InputStream.Seek(resumeOffset, SeekOrigin.Begin);
            ctx.SentBytes = resumeOffset;
            ctx.State = ConnectionContext.StateSendingFile;
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Transferring(resumeOffset, f.FileSize)); });
            _ = StreamChunksAsync(ctx);
        }
        catch (Exception ex)
        {
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed(ex.Message)); });
            await CloseContextAsync(ctx.Id, ex);
        }
    }

    private async Task StreamChunksAsync(ConnectionContext ctx)
    {
        if (ctx.InputStream is not { } input || ctx.TransferId is not { } tid) return;
        var fileSize = ctx.FileSize;
        var buf = new byte[ChunkSize];
        var offset = ctx.SentBytes;

        while (offset < fileSize && !ctx.Connection.IsClosed)
        {
            var toRead = (int)Math.Min(ChunkSize, fileSize - offset);
            int n;
            try { n = await input.ReadAsync(buf.AsMemory(0, toRead)); }
            catch (Exception ex)
            {
                _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed(ex.Message)); });
                await CloseContextAsync(ctx.Id, ex); return;
            }
            if (n <= 0) break;

            var slice = n == buf.Length ? buf : buf.AsSpan(0, n).ToArray();
            var body = FileChunkHeader.Encode(new FileChunkHeader(tid, 0, (ulong)offset), slice);
            try { await ctx.Connection.SendAsync(MessageType.FILE_CHUNK, body); }
            catch (Exception ex)
            {
                _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed(ex.Message)); });
                await CloseContextAsync(ctx.Id, ex); return;
            }
            offset += n;
            ctx.SentBytes = offset;
            var snap = offset;
            _ui.TryEnqueue(() =>
            {
                RecordProgress(ctx, snap, fileSize);
                if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Transferring(snap, fileSize));
            });
        }
        try { input.Dispose(); } catch { }
        ctx.InputStream = null;
    }

    // ─── 接收 ────────────────────────────────────────────────────────────

    /// <summary>
    /// 5 分钟窗口重放去重（security.md §重放）。返回 true 表示该 (peerFp, id) 是新消息
    /// 应处理；false 表示窗口内重复，调用方应丢弃。顺带惰性清理过期条目。
    /// 仅在 UI 线程调用（与 History 同线程），故 _seenMessages 无需加锁。
    /// </summary>
    private bool RegisterMessageId(string peerFp, string messageId)
    {
        if (string.IsNullOrEmpty(messageId)) return true; // 无 id 不去重，按原行为放行
        var now = DateTime.UtcNow;
        if (_seenMessages.Count > 0)
        {
            var stale = _seenMessages.Where(kv => now - kv.Value > ReplayWindow)
                                     .Select(kv => kv.Key).ToList();
            foreach (var k in stale) _seenMessages.Remove(k);
        }
        var key = peerFp + " " + messageId;
        if (_seenMessages.TryGetValue(key, out var seenAt) && now - seenAt <= ReplayWindow)
            return false;
        _seenMessages[key] = now;
        return true;
    }

    private void HandleReceivedText(ConnectionContext ctx, byte[] body)
    {
        if (ctx.Peer is null) return;
        TextMessage? text = null;
        try { text = MessageCodec.Decode<TextMessage>(body); } catch { }
        if (text is null) return;
        var peer = ctx.Peer!;
        var content = text.Content;
        var msgId = text.Id;
        _ui.TryEnqueue(() =>
        {
            if (!RegisterMessageId(peer.Fingerprint, msgId)) return; // 5min 窗口重放丢弃
            var item = HistoryItem.Create(peer, TransferDirection.Incoming,
                new HistoryKind.Text(content), new TransferStatus.Completed());
            History.Insert(0, item);
            RaiseEvent(new EngineEvent.HistoryAdded(item));
        });
    }

    private void HandleReceivedClipboard(ConnectionContext ctx, byte[] body)
    {
        if (ctx.Peer is null) return;
        ClipboardMessage? msg = null;
        try { msg = MessageCodec.Decode<ClipboardMessage>(body); } catch { }
        if (msg is null) return;
        var peerName = ctx.Peer.Name;
        var content = msg.Content;
        var kind = msg.Kind;
        _ui.TryEnqueue(() =>
        {
            var entry = ClipboardEntry.Create(peerName, content, kind);
            ClipboardInbox.Insert(0, entry);
            while (ClipboardInbox.Count > 50) ClipboardInbox.RemoveAt(ClipboardInbox.Count - 1);
            RaiseEvent(new EngineEvent.ClipboardReceived(entry));
        });
    }

    private void HandleReceivedFileOffer(ConnectionContext ctx, byte[] body)
    {
        if (ctx.Peer is null) return;
        FileOfferMessage? offer = null;
        try { offer = MessageCodec.Decode<FileOfferMessage>(body); } catch { }
        if (offer is null || offer.Files.Count == 0) return;
        if (!Guid.TryParse(offer.TransferId, out var tid)) return;

        var first = offer.Files[0];
        var peer = ctx.Peer!;
        var trusted = _trustStore.IsTrusted(ctx.Peer.Fingerprint);
        var offerId = offer.TransferId; // 用 transfer_id 作 FILE_OFFER 的去重 message id
        _ui.TryEnqueue(() =>
        {
            // 5min 窗口重放丢弃：同一 offer 被重放不再重复弹窗 / 重复入库
            if (!RegisterMessageId(peer.Fingerprint, offerId)) return;

            var resume = FindValidResumeRecord(peer, first);
            if (resume is not null && StartAutoResumeReceive(ctx, peer, tid, first, resume))
                return;

            var pending = new PendingFileOffer(tid, peer, first.Name, first.Size, first.Sha256, DateTime.Now);
            ctx.PendingOfferId = pending.Id;
            PendingFileOffers.Add(pending);
            RaiseEvent(new EngineEvent.OfferPending(pending));
            // 设置开启且对端已信任 → 自动接受（复用标准接受流程，会把该项移出 pending）。
            if (AutoAcceptFromTrusted && trusted) RespondToFileOffer(pending.Id, true);
        });
    }

    private ResumeRecord? FindValidResumeRecord(Device peer, FileMeta meta)
    {
        var record = _resumeStore.Find(peer.Fingerprint, meta.Sha256);
        if (record is null) return null;
        var invalid = record.FileSize != meta.Size
            || record.Sha256 != meta.Sha256
            || record.PeerFingerprint != peer.Fingerprint
            || record.BytesDone <= 0
            || record.BytesDone >= meta.Size
            || !File.Exists(record.SavedPath);
        if (!invalid)
        {
            try { invalid = new FileInfo(record.SavedPath).Length < record.BytesDone; }
            catch { invalid = true; }
        }
        if (!invalid) return record;
        _resumeStore.Clear(peer.Fingerprint, meta.Sha256);
        return null;
    }

    private bool StartAutoResumeReceive(
        ConnectionContext ctx,
        Device peer,
        Guid transferId,
        FileMeta meta,
        ResumeRecord record)
    {
        FileStream stream;
        try
        {
            stream = new FileStream(record.SavedPath, FileMode.Open, FileAccess.Write, FileShare.None);
            stream.SetLength(record.BytesDone);
            stream.Seek(record.BytesDone, SeekOrigin.Begin);
        }
        catch
        {
            _resumeStore.Clear(peer.Fingerprint, meta.Sha256);
            return false;
        }

        ctx.OutputStream = stream;
        ctx.SavedPath = record.SavedPath;
        ctx.FileSize = meta.Size;
        ctx.ExpectedSha256 = meta.Sha256;
        ctx.TransferId = transferId;
        ctx.PendingOfferId = null;
        ctx.ReceivedBytes = record.BytesDone;
        ctx.LastPersistedBytes = record.BytesDone;
        ctx.State = ConnectionContext.StateReceivingFile;

        var item = HistoryItem.Create(peer, TransferDirection.Incoming,
            new HistoryKind.File(meta.Name, meta.Size, record.SavedPath),
            new TransferStatus.Transferring(record.BytesDone, meta.Size));
        History.Insert(0, item);
        RaiseEvent(new EngineEvent.HistoryAdded(item));
        ctx.HistoryId = item.Id;

        _ = Task.Run(async () =>
        {
            var body = MessageCodec.Encode(new FileAcceptMessage(transferId.ToString(), 0, record.BytesDone));
            try { await ctx.Connection.SendAsync(MessageType.FILE_ACCEPT, body); }
            catch (Exception ex) { await CloseContextAsync(ctx.Id, ex); }
        });
        return true;
    }

    private async Task HandleReceivedChunkAsync(ConnectionContext ctx, byte[] body)
    {
        var parsed = FileChunkHeader.Decode(body);
        if (parsed is null) return;
        var header = parsed.Value.header;
        var data = parsed.Value.data;
        var offsetMismatch = ctx.TransferId != header.TransferId
            || header.Index != 0
            || header.Offset > long.MaxValue
            || (long)header.Offset != ctx.ReceivedBytes
            || ctx.ReceivedBytes + data.Length > ctx.FileSize;
        if (offsetMismatch)
        {
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed("FILE_CHUNK offset 不匹配")); });
            await CloseContextAsync(ctx.Id, null); return;
        }
        if (ctx.OutputStream is not { } output) return;
        try { await output.WriteAsync(data); }
        catch (Exception ex)
        {
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed(ex.Message)); });
            await CloseContextAsync(ctx.Id, ex); return;
        }
        ctx.ReceivedBytes += data.Length;
        var recv = ctx.ReceivedBytes;
        var size = ctx.FileSize;
        _ui.TryEnqueue(() =>
        {
            RecordProgress(ctx, recv, size);
            if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Transferring(recv, size));
        });

        if (ctx.ReceivedBytes < ctx.FileSize
            && ctx.ReceivedBytes - ctx.LastPersistedBytes >= ResumePersistInterval)
            PersistResumeRecord(ctx);

        if (ctx.ReceivedBytes >= ctx.FileSize)
        {
            try { output.Dispose(); } catch { }
            ctx.OutputStream = null;

            if (ctx.SavedPath is { } path && ctx.ExpectedSha256 is { } expected)
            {
                var actual = "";
                try { actual = await ComputeSha256Async(path); } catch { }
                if (actual != expected)
                {
                    _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Failed("校验失败")); });
                    ClearResumeRecord(ctx);
                    try { File.Delete(path); } catch { }
                    await CloseContextAsync(ctx.Id, null); return;
                }
                ClearResumeRecord(ctx);
            }

            if (ctx.TransferId is { } tid)
            {
                try
                {
                    var complete = new FileCompleteMessage(tid.ToString(), 0);
                    await ctx.Connection.SendAsync(MessageType.FILE_COMPLETE, MessageCodec.Encode(complete));
                }
                catch { }
            }
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Completed()); });
            await Task.Delay(150);
            await CloseContextAsync(ctx.Id, null);
        }
    }

    // ─── 关闭与辅助 ─────────────────────────────────────────────────────

    private Task CloseContextAsync(Guid id, Exception? ex)
    {
        if (!_contexts.TryRemove(id, out var ctx)) return Task.CompletedTask;
        if (ctx.PendingPairingId is { } pp)
            _ui.TryEnqueue(() => { var x = PendingPairings.FirstOrDefault(p => p.Id == pp); if (x is not null) PendingPairings.Remove(x); });
        if (ctx.PendingOfferId is { } po)
            _ui.TryEnqueue(() => { var x = PendingFileOffers.FirstOrDefault(o => o.Id == po); if (x is not null) PendingFileOffers.Remove(x); });
        if (ctx.State == ConnectionContext.StateReceivingFile
            && ctx.OutputStream is not null
            && ctx.ReceivedBytes < ctx.FileSize)
        {
            try { ctx.OutputStream.Flush(); } catch { }
            if (ctx.ReceivedBytes > ctx.LastPersistedBytes)
                PersistResumeRecord(ctx);
            _ui.TryEnqueue(() =>
            {
                if (ctx.HistoryId is { } h && !IsHistoryTerminal(h))
                    UpdateHistory(h, new TransferStatus.Failed("连接中断 · 等待续传"));
            });
        }
        else if (ctx.State == ConnectionContext.StateSendingFile && ctx.SentBytes < ctx.FileSize)
        {
            _ui.TryEnqueue(() =>
            {
                if (ctx.HistoryId is { } h && !IsHistoryTerminal(h))
                    UpdateHistory(h, new TransferStatus.Failed("连接中断"));
            });
        }
        try { ctx.InputStream?.Dispose(); } catch { }
        try { ctx.OutputStream?.Dispose(); } catch { }
        ctx.State = ConnectionContext.StateClosed;
        ctx.Connection.Close();
        return Task.CompletedTask;
    }

    private void PersistResumeRecord(ConnectionContext ctx)
    {
        if (ctx.Peer is null
            || ctx.TransferId is not { } tid
            || string.IsNullOrEmpty(ctx.ExpectedSha256)
            || string.IsNullOrEmpty(ctx.SavedPath)
            || ctx.ReceivedBytes <= 0
            || ctx.ReceivedBytes >= ctx.FileSize)
            return;

        var record = new ResumeRecord(
            ctx.Peer.Fingerprint,
            tid,
            Path.GetFileName(ctx.SavedPath),
            ctx.FileSize,
            ctx.ExpectedSha256,
            ctx.SavedPath,
            ctx.ReceivedBytes,
            DateTimeOffset.UtcNow);
        _resumeStore.Upsert(record);
        ctx.LastPersistedBytes = ctx.ReceivedBytes;
    }

    private void ClearResumeRecord(ConnectionContext ctx)
    {
        if (ctx.Peer is null || string.IsNullOrEmpty(ctx.ExpectedSha256)) return;
        _resumeStore.Clear(ctx.Peer.Fingerprint, ctx.ExpectedSha256);
    }

    private bool IsHistoryTerminal(Guid id)
    {
        var item = History.FirstOrDefault(h => h.Id == id);
        return item?.Status is TransferStatus.Completed
            or TransferStatus.Failed
            or TransferStatus.Canceled;
    }

    /// <summary>每秒一次：把进行中传输的瞬时速率按方向汇总成一个时间桶，推入环形序列。</summary>
    private void SampleThroughput()
    {
        double up = 0, down = 0;
        foreach (var h in History)
        {
            if (h.Status is TransferStatus.Transferring && TransferMetrics.TryGetValue(h.Id, out var m))
            {
                if (h.Direction == TransferDirection.Outgoing) up += m.BytesPerSec;
                else down += m.BytesPerSec;
            }
        }
        Append(_tpUp, up);
        Append(_tpDown, down);
        ThroughputUp = _tpUp.ToArray();
        ThroughputDown = _tpDown.ToArray();

        static void Append(List<double> buf, double v)
        {
            buf.Add(v);
            if (buf.Count > ThroughputBuckets) buf.RemoveRange(0, buf.Count - ThroughputBuckets);
        }
    }

    private void UpdateHistory(Guid id, TransferStatus status)
    {
        for (var i = 0; i < History.Count; i++)
            if (History[i].Id == id) { History[i] = History[i].WithStatus(status); break; }

        var terminal = status is TransferStatus.Completed
            or TransferStatus.Failed
            or TransferStatus.Canceled;
        if (terminal)
        {
            if (TransferMetrics.Remove(id))
                TransferMetricsChanged?.Invoke(id, null);

            // 跨端桥接：进入 terminal 时推 transfer_done（companion-bridges.md §2），
            // Web 客户端据此把进度条收尾 / 标失败。
            var ok = status is TransferStatus.Completed;
            var error = status switch
            {
                TransferStatus.Failed f => f.Reason,
                TransferStatus.Canceled => "canceled",
                _ => null,
            };
            RaiseEvent(new EngineEvent.TransferDone(id, ok, error));
        }
    }

    /// <summary>
    /// ctx 累计字节变化时调一下，刷新 EMA bytes/sec + ETA 到 TransferMetrics[historyId]。
    /// 节流：相邻样本至少 100ms；α=0.3 指数平滑。
    /// </summary>
    private void RecordProgress(ConnectionContext ctx, long currentBytes, long totalBytes)
    {
        if (ctx.HistoryId is not { } hid) return;
        var nowTicks = DateTime.UtcNow.Ticks;
        var prevTicks = ctx.LastSampleTicks;
        if (prevTicks != 0)
        {
            // TimeSpan.TicksPerMillisecond = 10000；100ms 节流。
            var dtTicks = nowTicks - prevTicks;
            if (dtTicks < 1_000_000) return;
            if (currentBytes >= ctx.LastSampleBytes)
            {
                var dtSec = dtTicks / (double)TimeSpan.TicksPerSecond;
                var inst = (currentBytes - ctx.LastSampleBytes) / dtSec;
                ctx.EmaBytesPerSec = ctx.EmaBytesPerSec == 0
                    ? inst
                    : 0.3 * inst + 0.7 * ctx.EmaBytesPerSec;
            }
        }
        ctx.LastSampleTicks = nowTicks;
        ctx.LastSampleBytes = currentBytes;

        var bps = ctx.EmaBytesPerSec;
        double? eta = bps > 1.0 && totalBytes > currentBytes
            ? (totalBytes - currentBytes) / bps
            : null;
        var m = new TransferMetrics(bps, eta);
        TransferMetrics[hid] = m;
        TransferMetricsChanged?.Invoke(hid, m);

        // 跨端桥接：把实时进度推给 Web 客户端（companion-bridges.md §2 transfer_progress），
        // 否则连到 Windows Gateway 的浏览器只能轮询 get_state、进度条不动。节流同 100ms。
        RaiseEvent(new EngineEvent.TransferProgress(hid, currentBytes, totalBytes, (long)bps));
    }

    private void RefreshTrusted()
    {
        Trusted.Clear();
        foreach (var r in _trustStore.Snapshot()) Trusted.Add(r);
    }

    private void OnDevicesChanged(IReadOnlyList<Device> list)
    {
        _ui.TryEnqueue(() =>
        {
            var byId = new Dictionary<string, Device>(StringComparer.Ordinal);
            foreach (var d in list) byId[d.Id] = d;

            for (var i = Devices.Count - 1; i >= 0; i--)
            {
                var existing = Devices[i];
                if (!byId.ContainsKey(existing.Id))
                {
                    Devices.RemoveAt(i);
                    RaiseEvent(new EngineEvent.DeviceRemoved(existing.Id));
                }
            }

            var have = new HashSet<string>(Devices.Select(d => d.Id), StringComparer.Ordinal);
            foreach (var d in list)
            {
                if (have.Add(d.Id))
                {
                    Devices.Add(d);
                    RaiseEvent(new EngineEvent.DeviceAdded(d));
                }
                else
                {
                    var idx = -1;
                    for (var i = 0; i < Devices.Count; i++) if (Devices[i].Id == d.Id) { idx = i; break; }
                    if (idx >= 0 && Devices[idx] != d) { Devices[idx] = d; RaiseEvent(new EngineEvent.DeviceUpdated(d)); }
                }
            }
        });
    }

    private void RaiseEvent(EngineEvent ev)
    {
        try { Event?.Invoke(ev); } catch { /* gateway 单点订阅，异常不影响 engine */ }
    }

    // SHA-256 流式

    private static async Task<string> ComputeSha256Async(string path)
    {
        using var sha = SHA256.Create();
        await using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        var hash = await sha.ComputeHashAsync(fs);
        var sb = new StringBuilder(hash.Length * 2);
        foreach (var b in hash) sb.AppendFormat("{0:x2}", b);
        return sb.ToString();
    }

    // 路径辅助

    private static string DefaultSaveDir(Device peer)
    {
        var docs = Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments);
        var dir = Path.Combine(docs, "MeshDrop", string.IsNullOrEmpty(peer.Name) ? peer.Id : peer.Name);
        Directory.CreateDirectory(dir);
        return dir;
    }

    private static string UniqueFilePath(string dir, string fileName)
    {
        var path = Path.Combine(dir, fileName);
        if (!File.Exists(path)) return path;
        var name = Path.GetFileNameWithoutExtension(fileName);
        var ext = Path.GetExtension(fileName);
        var n = 1;
        while (true)
        {
            var p = Path.Combine(dir, $"{name} ({n}){ext}");
            if (!File.Exists(p)) return p;
            n++;
        }
    }
}

// ─── ConnectionContext ──────────────────────────────────────────────

internal sealed class ConnectionContext
{
    // State 简单用 int 常量（避免 sealed record + pattern 复杂度）
    public const int StateAwaitingHello         = 1;
    public const int StateAwaitingPairApproval  = 2;
    public const int StateAwaitingHelloAck      = 3;
    public const int StateAwaitingFileAccept    = 4;
    public const int StateSendingFile           = 5;
    public const int StateReady                 = 6;
    public const int StateReceivingFile         = 7;
    public const int StateClosed                = 8;

    public Guid Id { get; } = Guid.NewGuid();
    public Connection Connection { get; }
    public RoleBase Role { get; }
    public int State { get; set; }

    public Device? Peer { get; set; }
    public Guid? HistoryId { get; set; }
    public Guid? TransferId { get; set; }
    public Guid? PendingOfferId { get; set; }
    public Guid? PendingPairingId { get; set; }

    public FileStream? InputStream { get; set; }
    public FileStream? OutputStream { get; set; }
    public long FileSize { get; set; }
    public long SentBytes { get; set; }
    public long ReceivedBytes { get; set; }
    public long LastPersistedBytes { get; set; }
    public string? SavedPath { get; set; }
    public string? ExpectedSha256 { get; set; }

    // 速率窗口：上次采样时刻 + 累计字节，用来算 Δbytes / Δtime；α=0.3 EMA。
    public long LastSampleTicks { get; set; }
    public long LastSampleBytes { get; set; }
    public double EmaBytesPerSec { get; set; }

    public ConnectionContext(Connection conn, RoleBase role, int state)
    {
        Connection = conn; Role = role; State = state;
    }

    // 嵌套类型 Role 与同名属性会触发 CS0102；改名 RoleBase 让二者共存。
    public abstract record RoleBase;
    public sealed record RoleServer : RoleBase;
    public static readonly RoleServer RoleServerSingleton = new();
    public sealed record RoleClient(Device Target, Payload Payload) : RoleBase;

    public abstract record Payload;
    public sealed record PayloadText(string Content) : Payload;
    public sealed record PayloadClipboard(string Content, string Kind) : Payload;
    public sealed record PayloadFile(string SourcePath, long FileSize, string Sha256, string FileName) : Payload;
}
