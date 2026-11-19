using MeshDrop.Gateway;
using Xunit;

namespace MeshDrop.Transport.Tests;

public sealed class GatewayUploadTests
{
    [Theory]
    [InlineData(0)]
    [InlineData(131071)]
    public async Task MultipartPreservesFileBytesAndName(int length)
    {
        var root = Directory.CreateTempSubdirectory();
        try
        {
            var bytes = new byte[length];
            new Random(42).NextBytes(bytes);
            using var form = new MultipartFormDataContent();
            form.Add(new ByteArrayContent(bytes), "file", "小文件.bin");
            var encoded = await form.ReadAsByteArrayAsync();
            using var stream = new MemoryStream(encoded);
            var path = await GatewayUpload.SaveAsync(stream, form.Headers.ContentType!.ToString(),
                encoded.Length, root.FullName, default);
            Assert.Equal("小文件.bin", Path.GetFileName(path));
            Assert.Equal(bytes, await File.ReadAllBytesAsync(path));
        }
        finally { root.Delete(true); }
    }
}
