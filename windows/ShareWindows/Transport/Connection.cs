using System;
using System.IO;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using MeshDrop.Protocol;

namespace MeshDrop.Transport;

/// <summary>
/// 包装一个 TCP socket，按帧 (Frame) 读写。
/// 串行 send（SemaphoreSlim 互斥）；读循环在后台 task。
/// </summary>
public sealed class Connection : IDisposable
{
    private readonly TcpClient _tcp;
    private readonly string? _host;
    private readonly int _port;
    private readonly SemaphoreSlim _sendLock = new(1, 1);
    private readonly CancellationTokenSource _cts = new();

    private NetworkStream? _stream;
    private bool _closeNotified;

    public bool IsClosed => _cts.IsCancellationRequested;

    private Connection(TcpClient tcp, string? host, int port)
    {
        _tcp = tcp;
        _host = host;
        _port = port;
    }

    public static Connection ForIncoming(TcpClient tcp) => new(tcp, null, 0);

    public static Connection ForOutgoing(string host, int port) =>
        new(new TcpClient(), host, port);

    public void Start(
        Func<Task> onReady,
        Func<byte, byte[], Task> onMessage,
        Func<Exception?, Task> onClose)
    {
        _ = Task.Run(async () =>
        {
            try
            {
                if (_host is not null)
                    await _tcp.ConnectAsync(_host, _port, _cts.Token);
                _stream = _tcp.GetStream();
                await onReady();
                await ReadLoopAsync(onMessage, onClose);
            }
            catch (Exception ex)
            {
                await NotifyCloseAsync(onClose, ex);
            }
        });
    }

    public async Task SendAsync(byte type, ReadOnlyMemory<byte> body)
    {
        if (IsClosed) throw new IOException("connection closed");
        var frame = Frame.Encode(type, body.Span);
        await _sendLock.WaitAsync(_cts.Token);
        try
        {
            var stream = _stream ?? throw new IOException("not ready");
            await stream.WriteAsync(frame, _cts.Token);
            await stream.FlushAsync(_cts.Token);
        }
        finally
        {
            _sendLock.Release();
        }
    }

    public void Close()
    {
        if (_cts.IsCancellationRequested) return;
        _cts.Cancel();
        try { _stream?.Close(); } catch { }
        try { _tcp.Close(); } catch { }
    }

    public void Dispose()
    {
        Close();
        _sendLock.Dispose();
        _cts.Dispose();
    }

    private async Task ReadLoopAsync(
        Func<byte, byte[], Task> onMessage,
        Func<Exception?, Task> onClose)
    {
        var stream = _stream!;
        var buf = new byte[64 * 1024];
        var pending = Array.Empty<byte>();

        while (!_cts.IsCancellationRequested)
        {
            int n;
            try
            {
                n = await stream.ReadAsync(buf, _cts.Token);
            }
            catch (Exception ex)
            {
                await NotifyCloseAsync(onClose, ex);
                return;
            }
            if (n <= 0)
            {
                await NotifyCloseAsync(onClose, null);
                return;
            }

            // 拼接
            var merged = new byte[pending.Length + n];
            pending.CopyTo(merged, 0);
            buf.AsSpan(0, n).CopyTo(merged.AsSpan(pending.Length));
            pending = merged;

            // 解出所有 frame
            var offset = 0;
            while (true)
            {
                var r = Frame.Decode(pending.AsSpan(offset));
                switch (r.Status)
                {
                    case Frame.DecodeStatus.NeedMore:
                        if (offset > 0)
                            pending = pending.AsSpan(offset).ToArray();
                        goto next;
                    case Frame.DecodeStatus.LengthOutOfRange:
                        await NotifyCloseAsync(onClose, new IOException("frame length OOR"));
                        return;
                    case Frame.DecodeStatus.Ok:
                        offset += r.Consumed;
                        try { await onMessage(r.Type, r.Body); }
                        catch (Exception ex) { await NotifyCloseAsync(onClose, ex); return; }
                        break;
                }
            }
            next: ;
        }
    }

    private async Task NotifyCloseAsync(Func<Exception?, Task> onClose, Exception? ex)
    {
        if (_closeNotified) return;
        _closeNotified = true;
        Close();
        try { await onClose(ex); } catch { }
    }
}
