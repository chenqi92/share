using System;
using System.IO;
using System.Threading;
using System.Threading.Tasks;
using MeshDrop.Transport;
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Net.Http.Headers;

namespace MeshDrop.Gateway;

internal static class GatewayUpload
{
    internal const long MaxRequestSize = (4L << 30) + 64 * 1024;
    internal static string Root => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MeshDrop", "uploads");

    internal static async Task<string> SaveAsync(Stream stream, string? contentType, long length, string root, CancellationToken ct)
    {
        if (!MediaTypeHeaderValue.TryParse(contentType, out var type) ||
            !string.Equals(type.MediaType.Value, "multipart/form-data", StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("Expected a multipart upload.");
        var boundary = HeaderUtilities.RemoveQuotes(type.Boundary).Value;
        if (string.IsNullOrEmpty(boundary) || boundary.Length > 70)
            throw new InvalidDataException("Invalid multipart boundary.");

        if (length <= 0 || length > MaxRequestSize) throw new InvalidDataException("Invalid upload length.");
        using var body = new RequestBody(stream, length);
        var reader = new MultipartReader(boundary, body) { BodyLengthLimit = 4L << 30 };
        var section = await reader.ReadNextSectionAsync(ct);
        var file = section?.AsFileSection();
        if (file?.Name != "file") throw new InvalidDataException("Missing file part.");

        var directory = Path.Combine(root, Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        try
        {
            var name = ReceiveFilePaths.SafeSegment(Path.GetFileName(file.FileName.Replace('\\', '/')), "file");
            var path = Path.Combine(directory, name);
            await using var output = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
            await section!.Body.CopyToAsync(output, ct);
            if (await reader.ReadNextSectionAsync(ct) is not null)
                throw new InvalidDataException("Expected one file.");
            return path;
        }
        catch
        {
            Directory.Delete(directory, recursive: true);
            throw;
        }
    }

    // The HTTP client waits for our response before closing the TLS connection.
    // Present EOF to the multipart reader exactly at the declared body length.
    private sealed class RequestBody(Stream source, long remaining) : Stream
    {
        public override bool CanRead => true;
        public override bool CanSeek => false;
        public override bool CanWrite => false;
        public override long Length => throw new NotSupportedException();
        public override long Position { get => throw new NotSupportedException(); set => throw new NotSupportedException(); }
        public override int Read(byte[] buffer, int offset, int count) =>
            ReadAsync(buffer, offset, count).GetAwaiter().GetResult();
        public override Task<int> ReadAsync(byte[] buffer, int offset, int count, CancellationToken token) =>
            ReadAsync(buffer.AsMemory(offset, count), token).AsTask();
        public override async ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken token = default)
        {
            if (remaining == 0 || buffer.Length == 0) return 0;
            int read = await source.ReadAsync(buffer[..(int)Math.Min(buffer.Length, remaining)], token);
            if (read == 0) throw new InvalidDataException("Truncated upload.");
            remaining -= read;
            return read;
        }
        public override void Flush() { }
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => throw new NotSupportedException();
    }

    internal static bool IsUpload(string? path)
    {
        if (string.IsNullOrEmpty(path) || !Path.IsPathFullyQualified(path)) return false;
        var file = new FileInfo(path);
        var directory = file.Directory;
        return file.Exists && directory != null && Guid.TryParseExact(directory.Name, "N", out _)
            && string.Equals(directory.Parent?.FullName, Root, StringComparison.OrdinalIgnoreCase)
            && directory.LinkTarget == null && file.LinkTarget == null;
    }
}
