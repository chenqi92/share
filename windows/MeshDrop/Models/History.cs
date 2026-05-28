using System;

namespace MeshDrop.Models;

public enum TransferDirection { Outgoing, Incoming }

public abstract record HistoryKind
{
    public sealed record Text(string Content) : HistoryKind;
    public sealed record File(string Name, long Size, string? LocalPath) : HistoryKind;
}

public abstract record TransferStatus
{
    public sealed record Pending : TransferStatus;
    public sealed record WaitingApproval : TransferStatus;
    public sealed record Transferring(long BytesDone, long BytesTotal) : TransferStatus
    {
        public double Fraction => BytesTotal > 0 ? (double)BytesDone / BytesTotal : 0.0;
    }
    public sealed record Completed : TransferStatus;
    public sealed record Failed(string Reason) : TransferStatus;
    public sealed record Canceled : TransferStatus;
}

/// <summary>
/// 进行中传输的实时指标。仅在 Transferring 阶段有意义，进入 terminal 时被清。
/// </summary>
public sealed record TransferMetrics(double BytesPerSec, double? EtaSeconds);

public sealed record HistoryItem(
    Guid Id,
    Device Peer,
    TransferDirection Direction,
    HistoryKind Kind,
    TransferStatus Status,
    DateTime CreatedAt)
{
    public static HistoryItem Create(Device peer, TransferDirection direction, HistoryKind kind, TransferStatus status) =>
        new(Guid.NewGuid(), peer, direction, kind, status, DateTime.Now);

    public string FormattedTime => CreatedAt.ToString("HH:mm:ss");

    public HistoryItem WithStatus(TransferStatus newStatus) => this with { Status = newStatus };
}

public static class ByteFormat
{
    public static string Format(long n)
    {
        if (n < 1024) return $"{n} B";
        var kb = n / 1024.0;
        if (kb < 1024) return $"{kb:F1} KB";
        var mb = kb / 1024.0;
        if (mb < 1024) return $"{mb:F1} MB";
        var gb = mb / 1024.0;
        return $"{gb:F2} GB";
    }
}
