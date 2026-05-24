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
/// 顶层引擎：进程单例。持有 Identity、Discovery、TrustStore，对外暴露设备
/// 列表、历史、待审配对/文件 offer。整链路对齐 Apple/Android。
/// </summary>
public sealed partial class ShareEngine : ObservableObject
{
    private const int ChunkSize = 256 * 1024;
    private static readonly Lazy<ShareEngine> s_lazy = new(() => new ShareEngine());
    public static ShareEngine Shared => s_lazy.Value;

    private readonly DispatcherQueue _ui;
    private readonly TrustStore _trustStore = new();
    private readonly MdnsDiscovery _discovery;
    private readonly ConcurrentDictionary<Guid, ConnectionContext> _contexts = new();

    private TcpListener? _listener;
    private CancellationTokenSource? _cts;

    public Identity Identity { get; }
    public string DisplayName { get; }
    public string? Model { get; }

    public ObservableCollection<Device> Devices { get; } = new();
    public ObservableCollection<HistoryItem> History { get; } = new();
    public ObservableCollection<PendingPairing> PendingPairings { get; } = new();
    public ObservableCollection<PendingFileOffer> PendingFileOffers { get; } = new();
    public ObservableCollection<TrustRecord> Trusted { get; } = new();

    private ShareEngine()
    {
        _ui = DispatcherQueue.GetForCurrentThread()
              ?? throw new InvalidOperationException("ShareEngine must be created on UI thread");
        Identity = Identity.LoadOrCreate();
        DisplayName = Environment.MachineName;
        Model = "Windows PC";

        _discovery = new MdnsDiscovery(Identity, DisplayName, Model);
        _discovery.DevicesChanged += OnDevicesChanged;

        foreach (var r in _trustStore.Snapshot()) Trusted.Add(r);
    }

    // ─── 生命周期 ───────────────────────────────────────────────────────

    public async Task StartAsync()
    {
        if (_listener is not null) return;

        _listener = new TcpListener(IPAddress.Any, 0);
        _listener.Start();
        var port = (ushort)((IPEndPoint)_listener.LocalEndpoint).Port;

        _cts = new CancellationTokenSource();
        _discovery.Start(port);

        _ = AcceptLoopAsync(_cts.Token);
        await Task.CompletedTask;
    }

    public void Stop()
    {
        _cts?.Cancel();
        _listener?.Stop();
        _listener = null;
        _discovery.Stop();
        foreach (var ctx in _contexts.Values) ctx.Connection.Close();
        _contexts.Clear();
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

    // ─── 出方：文件 ──────────────────────────────────────────────────────

    public void SendFile(Device device, string sourcePath)
    {
        var info = new FileInfo(sourcePath);
        var item = HistoryItem.Create(device, TransferDirection.Outgoing,
            new HistoryKind.File(info.Name, info.Length, sourcePath),
            new TransferStatus.Pending());
        History.Insert(0, item);

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
            ctx.ExpectedSha256 = offer.Sha256;
            ctx.TransferId = offer.Id;
            ctx.PendingOfferId = null;
            ctx.State = ConnectionContext.StateReceivingFile;

            var item = HistoryItem.Create(offer.Peer, TransferDirection.Incoming,
                new HistoryKind.File(offer.FileName, offer.FileSize, path),
                new TransferStatus.Transferring(0, offer.FileSize));
            History.Insert(0, item);
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
        { await ClientStartSendingAsync(ctx); return; }

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

        if (state == ConnectionContext.StateReady && type == MessageType.FILE_OFFER)
        { HandleReceivedFileOffer(ctx, body); return; }

        if (state == ConnectionContext.StateReceivingFile && type == MessageType.FILE_CHUNK)
        { await HandleReceivedChunkAsync(ctx, body); return; }

        if (type == MessageType.PING)
        { try { await ctx.Connection.SendAsync(MessageType.PONG, Encoding.UTF8.GetBytes("{}")); } catch { } return; }

        if (type == MessageType.PONG) return;

        await CloseContextAsync(ctxId, null);
    }

    // ─── HELLO 握手 ─────────────────────────────────────────────────────

    private async Task SendInitialHelloAsync(Guid ctxId)
    {
        if (!_contexts.TryGetValue(ctxId, out var ctx)) return;
        var hello = new HelloMessage(Identity.Id, DisplayName, "windows", Model, Identity.Fingerprint, new() { 1 });
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
            _ui.TryEnqueue(() => PendingPairings.Add(req));
        }
    }

    private async Task SendAckAndReadyAsync(ConnectionContext ctx, Device peer)
    {
        var ack = new HelloAckMessage(Identity.Id, DisplayName, "windows", Model,
            Identity.Fingerprint, new() { 1 }, 1);
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

    private async Task ClientStartSendingAsync(ConnectionContext ctx)
    {
        if (ctx.Role is not ConnectionContext.RoleClient role) return;
        if (role.Payload is not ConnectionContext.PayloadFile f) return;
        try
        {
            ctx.InputStream = new FileStream(f.SourcePath, FileMode.Open, FileAccess.Read, FileShare.Read);
            ctx.State = ConnectionContext.StateSendingFile;
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Transferring(0, f.FileSize)); });
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
        long offset = 0;

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
            _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Transferring(snap, fileSize)); });
        }
        try { input.Dispose(); } catch { }
        ctx.InputStream = null;
    }

    // ─── 接收 ────────────────────────────────────────────────────────────

    private void HandleReceivedText(ConnectionContext ctx, byte[] body)
    {
        if (ctx.Peer is null) return;
        TextMessage? text = null;
        try { text = MessageCodec.Decode<TextMessage>(body); } catch { }
        if (text is null) return;
        var peer = ctx.Peer;
        var content = text.Content;
        _ui.TryEnqueue(() =>
        {
            History.Insert(0, HistoryItem.Create(peer, TransferDirection.Incoming,
                new HistoryKind.Text(content), new TransferStatus.Completed()));
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
        var pending = new PendingFileOffer(tid, ctx.Peer, first.Name, first.Size, first.Sha256, DateTime.Now);
        ctx.PendingOfferId = pending.Id;
        _ui.TryEnqueue(() => PendingFileOffers.Add(pending));
    }

    private async Task HandleReceivedChunkAsync(ConnectionContext ctx, byte[] body)
    {
        var parsed = FileChunkHeader.Decode(body);
        if (parsed is null) return;
        var data = parsed.Value.data;
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
        _ui.TryEnqueue(() => { if (ctx.HistoryId is { } h) UpdateHistory(h, new TransferStatus.Transferring(recv, size)); });

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
                    try { File.Delete(path); } catch { }
                    await CloseContextAsync(ctx.Id, null); return;
                }
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
        try { ctx.InputStream?.Dispose(); } catch { }
        try { ctx.OutputStream?.Dispose(); } catch { }
        ctx.State = ConnectionContext.StateClosed;
        ctx.Connection.Close();
        return Task.CompletedTask;
    }

    private void UpdateHistory(Guid id, TransferStatus status)
    {
        for (var i = 0; i < History.Count; i++)
            if (History[i].Id == id) { History[i] = History[i].WithStatus(status); return; }
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
            Devices.Clear();
            foreach (var d in list) Devices.Add(d);
        });
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
    public Role Role { get; }
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
    public string? SavedPath { get; set; }
    public string? ExpectedSha256 { get; set; }

    public ConnectionContext(Connection conn, Role role, int state)
    {
        Connection = conn; Role = role; State = state;
    }

    public abstract record Role;
    public sealed record RoleServer : Role;
    public static readonly RoleServer RoleServerSingleton = new();
    public sealed record RoleClient(Device Target, Payload Payload) : Role;

    public abstract record Payload;
    public sealed record PayloadText(string Content) : Payload;
    public sealed record PayloadFile(string SourcePath, long FileSize, string Sha256, string FileName) : Payload;
}
