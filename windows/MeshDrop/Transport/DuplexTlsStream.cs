using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace MeshDrop.Transport;

// Bouncy Castle implements synchronous TLS I/O. Stream's default async adapter
// serializes reads AND writes: a pending read then blocks a user's FILE_ACCEPT.
// Give each direction its own worker; callers serialize writes and close the
// underlying socket to interrupt in-flight I/O on cancellation.
internal sealed class DuplexTlsStream(Stream inner) : Stream
{
    public override bool CanRead => inner.CanRead;
    public override bool CanWrite => inner.CanWrite;
    public override bool CanSeek => false;
    public override long Length => throw new NotSupportedException();
    public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
    public override int Read(byte[] buffer, int offset, int count) => inner.Read(buffer, offset, count);
    public override int Read(Span<byte> buffer) => inner.Read(buffer);
    public override void Write(byte[] buffer, int offset, int count) => inner.Write(buffer, offset, count);
    public override void Write(ReadOnlySpan<byte> buffer) => inner.Write(buffer);
    public override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken token) =>
        Task.Run(() => inner.Read(buffer, offset, count), token);
    public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken token = default) =>
        new(Task.Run(() => inner.Read(buffer.Span), token));
    public override Task WriteAsync(byte[] buffer, int offset, int count, CancellationToken token) =>
        Task.Run(() => inner.Write(buffer, offset, count), token);
    public override ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken token = default) =>
        new(Task.Run(() => inner.Write(buffer.Span), token));
    public override void Flush() => inner.Flush();
    public override Task FlushAsync(CancellationToken token) => Task.Run(inner.Flush, token);
    public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
    public override void SetLength(long value) => throw new NotSupportedException();
    protected override void Dispose(bool disposing)
    {
        if (disposing) inner.Dispose();
        base.Dispose(disposing);
    }
}
