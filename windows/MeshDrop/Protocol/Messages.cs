using System;
using System.Buffers.Binary;
using System.Collections.Generic;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MeshDrop.Protocol;

public sealed record HelloMessage(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("os")] string Os,
    [property: JsonPropertyName("model")] string? Model,
    [property: JsonPropertyName("fp")] string Fp,
    [property: JsonPropertyName("protocol_versions")] List<byte> ProtocolVersions);

public sealed record HelloAckMessage(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("os")] string Os,
    [property: JsonPropertyName("model")] string? Model,
    [property: JsonPropertyName("fp")] string Fp,
    [property: JsonPropertyName("protocol_versions")] List<byte> ProtocolVersions,
    [property: JsonPropertyName("selected_version")] byte SelectedVersion);

public sealed record TextMessage(
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("content")] string Content,
    [property: JsonPropertyName("ts")] long Ts);

public sealed record FileMeta(
    [property: JsonPropertyName("index")] int Index,
    [property: JsonPropertyName("name")] string Name,
    [property: JsonPropertyName("size")] long Size,
    [property: JsonPropertyName("sha256")] string Sha256);

public sealed record FileOfferMessage(
    [property: JsonPropertyName("transfer_id")] string TransferId,
    [property: JsonPropertyName("files")] List<FileMeta> Files);

public sealed record FileAcceptMessage(
    [property: JsonPropertyName("transfer_id")] string TransferId,
    [property: JsonPropertyName("index")] int Index,
    [property: JsonPropertyName("resume_offset")] long ResumeOffset);

public sealed record FileRejectMessage(
    [property: JsonPropertyName("transfer_id")] string TransferId,
    [property: JsonPropertyName("index")] int Index,
    [property: JsonPropertyName("reason")] string Reason);

public sealed record FileCompleteMessage(
    [property: JsonPropertyName("transfer_id")] string TransferId,
    [property: JsonPropertyName("index")] int Index);

public static class MessageCodec
{
    private static readonly JsonSerializerOptions s_options = new()
    {
        PropertyNamingPolicy = null,    // 已用 JsonPropertyName 显式声明
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    public static byte[] Encode<T>(T value) =>
        Encoding.UTF8.GetBytes(JsonSerializer.Serialize(value, s_options));

    public static T Decode<T>(byte[] body) =>
        JsonSerializer.Deserialize<T>(Encoding.UTF8.GetString(body), s_options)
        ?? throw new InvalidOperationException("decode null");
}

/// <summary>
/// FILE_CHUNK 二进制头部：
/// [transfer_id (16)][index (u32 BE)][offset (u64 BE)][data...]
/// </summary>
public readonly record struct FileChunkHeader(Guid TransferId, uint Index, ulong Offset)
{
    public const int Size = 16 + 4 + 8;

    public static byte[] Encode(FileChunkHeader header, ReadOnlySpan<byte> data)
    {
        var buf = new byte[Size + data.Length];
        // .NET Guid 的字节顺序：前 4 字节是 Data1 (LE int32)，要转为我们规范的 big-endian
        // 用 ToByteArray(bigEndian: true) 保证全 BE
        var guidBytes = header.TransferId.ToByteArray(bigEndian: true);
        guidBytes.CopyTo(buf, 0);
        BinaryPrimitives.WriteUInt32BigEndian(buf.AsSpan(16, 4), header.Index);
        BinaryPrimitives.WriteUInt64BigEndian(buf.AsSpan(20, 8), header.Offset);
        data.CopyTo(buf.AsSpan(Size));
        return buf;
    }

    public static (FileChunkHeader header, byte[] data)? Decode(ReadOnlySpan<byte> body)
    {
        if (body.Length < Size) return null;
        var transferId = new Guid(body.Slice(0, 16), bigEndian: true);
        var index = BinaryPrimitives.ReadUInt32BigEndian(body.Slice(16, 4));
        var offset = BinaryPrimitives.ReadUInt64BigEndian(body.Slice(20, 8));
        var data = body.Slice(Size).ToArray();
        return (new FileChunkHeader(transferId, index, offset), data);
    }
}
