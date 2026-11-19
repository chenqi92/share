using System;
using System.Text.Json;
using MeshDrop.Models;

namespace MeshDrop.Gateway;

internal static class GatewayWire
{
    private static readonly JsonSerializerOptions WireJson = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase };

    internal static string Event(string type, object? payload) =>
        JsonSerializer.Serialize(new
        {
            v = 1,
            id = "evt-" + Guid.NewGuid().ToString("N").Substring(0, 12),
            type,
            ts = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            payload,
        }, WireJson);

    internal static string Reply(string id, bool ok, string? error = null, object? result = null)
    {
        return JsonSerializer.Serialize(new
        {
            v = 1,
            id,
            ok,
            error,
            result,
        }, WireJson);
    }
}

internal sealed record BridgeDevice(string Id, string DisplayName, string Kind, string Model,
                                    string Ip, int RttMs, bool Online, bool Trusted, bool Busy)
{
    public static BridgeDevice From(Device d, bool trusted, bool busy) => new(
        d.Id, d.Name,
        d.Os switch
        {
            DeviceOS.Macos => "mac",
            DeviceOS.Windows => "win",
            DeviceOS.Ios => "ios",
            DeviceOS.Android => "android",
            DeviceOS.Linux => "linux",
            _ => "linux",
        },
        d.Model ?? "",
        d.Host ?? "",
        0,
        true,
        trusted, busy);
}

internal sealed record BridgePairing(string Id, string PeerName, string Fingerprint, long CreatedAt)
{
    public static BridgePairing From(PendingPairing p) => new(
        p.Id.ToString(), p.Peer.Name, p.Peer.HumanFingerprint,
        new DateTimeOffset(p.ReceivedAt).ToUnixTimeSeconds());
}

internal sealed record BridgeOffer(string Id, string PeerId, string PeerName, string Kind,
                                   object[] Files, long CreatedAt)
{
    public static BridgeOffer From(PendingFileOffer o) => new(
        o.Id.ToString(), o.Peer.Id, o.Peer.Name, "file",
        new object[] { new { name = o.FileName, sizeBytes = o.FileSize } },
        new DateTimeOffset(o.ReceivedAt).ToUnixTimeSeconds());
}

internal sealed record BridgeHistory(string Id, string Direction, string PeerName,
                                     string Kind, string? Text, object[]? Files,
                                     long? BytesTransferred, bool Ok, long CompletedAt, string Status, string? Error)
{
    public static BridgeHistory From(HistoryItem item)
    {
        var outgoing = item.Direction == TransferDirection.Outgoing;
        var file = item.Kind as HistoryKind.File;
        var status = item.Status switch
        {
            TransferStatus.Pending => "queued",
            TransferStatus.WaitingApproval => "waiting",
            TransferStatus.Transferring => outgoing ? "sending" : "receiving",
            TransferStatus.Completed => "done",
            TransferStatus.Canceled => "canceled",
            _ => "failed",
        };
        long? done = item.Status switch
        {
            TransferStatus.Transferring t => t.BytesDone,
            TransferStatus.Completed => file?.Size,
            _ => null,
        };
        return new(item.Id.ToString(), outgoing ? "sent" : "received", item.Peer.Name,
            file == null ? "text" : "file", (item.Kind as HistoryKind.Text)?.Content,
            file == null ? null : new object[] { new { name = file.Name, sizeBytes = file.Size } },
            done, item.Status is TransferStatus.Completed, new DateTimeOffset(item.CreatedAt).ToUnixTimeSeconds(),
            status, (item.Status as TransferStatus.Failed)?.Reason);
    }
}

internal sealed record BridgeClipboard(string Id, string PeerName, string Kind, string Content, long Ts)
{
    public static BridgeClipboard From(ClipboardEntry e) => new(
        e.Id.ToString(), e.PeerName, e.Kind, e.Content,
        new DateTimeOffset(e.ReceivedAt).ToUnixTimeSeconds());
}
