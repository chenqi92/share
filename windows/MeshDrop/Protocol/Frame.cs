using System;
using System.Buffers.Binary;

namespace MeshDrop.Protocol;

/// <summary>
/// 帧编解码。规范见 protocol/transport.md。
/// [u32 BE length][u8 type][body (length-1 bytes)]
/// </summary>
public static class Frame
{
    public const int MaxLength = 16 * 1024 * 1024;

    public static byte[] Encode(byte type, ReadOnlySpan<byte> body)
    {
        var length = body.Length + 1;
        if (length < 1 || length > MaxLength)
            throw new ArgumentException($"frame length out of range: {length}");
        var buf = new byte[4 + length];
        BinaryPrimitives.WriteUInt32BigEndian(buf.AsSpan(0, 4), (uint)length);
        buf[4] = type;
        body.CopyTo(buf.AsSpan(5));
        return buf;
    }

    public enum DecodeStatus { NeedMore, Ok, LengthOutOfRange }

    public readonly record struct DecodeResult(
        DecodeStatus Status,
        byte Type,
        byte[] Body,
        int Consumed);

    public static DecodeResult Decode(ReadOnlySpan<byte> buf)
    {
        if (buf.Length < 4)
            return new DecodeResult(DecodeStatus.NeedMore, 0, Array.Empty<byte>(), 0);
        var len = BinaryPrimitives.ReadUInt32BigEndian(buf.Slice(0, 4));
        if (len < 1 || len > MaxLength)
            return new DecodeResult(DecodeStatus.LengthOutOfRange, 0, Array.Empty<byte>(), 0);
        var total = 4 + (int)len;
        if (buf.Length < total)
            return new DecodeResult(DecodeStatus.NeedMore, 0, Array.Empty<byte>(), 0);
        var type = buf[4];
        var body = buf.Slice(5, (int)len - 1).ToArray();
        return new DecodeResult(DecodeStatus.Ok, type, body, total);
    }
}

public static class MessageType
{
    public const byte HELLO         = 0x01;
    public const byte HELLO_ACK     = 0x02;
    public const byte TEXT          = 0x10;
    public const byte CLIPBOARD     = 0x11;
    public const byte FILE_OFFER    = 0x20;
    public const byte FILE_ACCEPT   = 0x21;
    public const byte FILE_REJECT   = 0x22;
    public const byte FILE_COMPLETE = 0x23;
    public const byte FILE_CANCEL   = 0x25;
    public const byte FILE_CHUNK    = 0x30;
    public const byte PING          = 0xF0;
    public const byte PONG          = 0xF1;
}
