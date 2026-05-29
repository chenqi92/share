using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using MeshDrop.Models;
using MeshDrop.Transport;

namespace MeshDrop.Gateway;

/// <summary>
/// 把 protocol/companion-bridges.md §1 命令路由到 ShareEngine。
/// 输入 JSON 对象，输出回执 JSON 对象。
/// </summary>
internal sealed class GatewayCommands
{
    private readonly ShareEngine _engine;

    public GatewayCommands(ShareEngine engine) { _engine = engine; }

    public string Dispatch(string requestJson)
    {
        Cmd? cmd = null;
        try { cmd = JsonSerializer.Deserialize<Cmd>(requestJson); } catch { }
        if (cmd is null || string.IsNullOrEmpty(cmd.Type))
            return Reply("", false, "invalid_request");

        try
        {
            switch (cmd.Type)
            {
                case "list_devices":
                    return Reply(cmd.Id, true, null, new { devices = _engine.Devices.Select(BridgeDevice.From).ToArray() });
                case "get_state":
                    return Reply(cmd.Id, true, null, new
                    {
                        self = BridgeDevice.From(_engine.SelfDevice),
                        devices = _engine.Devices.Select(BridgeDevice.From).ToArray(),
                        history = _engine.History.Select(BridgeHistory.From).ToArray(),
                        pendingPairings = _engine.PendingPairings.Select(BridgePairing.From).ToArray(),
                        pendingOffers = _engine.PendingFileOffers.Select(BridgeOffer.From).ToArray(),
                    });
                case "send_text":
                    {
                        var p = cmd.Payload.Deserialize<SendTextPayload>() ?? new SendTextPayload();
                        var dev = _engine.Devices.FirstOrDefault(d => d.Id == p.PeerId);
                        if (dev is null) return Reply(cmd.Id, false, "peer_not_found");
                        _engine.SendText(dev, p.Text ?? "");
                        return Reply(cmd.Id, true);
                    }
                case "send_clipboard":
                    {
                        var p = cmd.Payload.Deserialize<SendClipboardPayload>() ?? new SendClipboardPayload();
                        var dev = _engine.Devices.FirstOrDefault(d => d.Id == p.PeerId);
                        if (dev is null) return Reply(cmd.Id, false, "peer_not_found");
                        var content = p.Content ?? "";
                        if (string.IsNullOrEmpty(content)) return Reply(cmd.Id, false, "empty_content");
                        var kind = string.IsNullOrEmpty(p.Kind) ? ShareEngine.ClipKind(content) : p.Kind;
                        _engine.PushClipboard(dev, content, kind);
                        return Reply(cmd.Id, true);
                    }
                case "send_file_ref":
                    {
                        var p = cmd.Payload.Deserialize<SendFileRefPayload>() ?? new SendFileRefPayload();
                        var dev = _engine.Devices.FirstOrDefault(d => d.Id == p.PeerId);
                        if (dev is null) return Reply(cmd.Id, false, "peer_not_found");
                        if (string.IsNullOrEmpty(p.FileRef) || !System.IO.File.Exists(p.FileRef))
                            return Reply(cmd.Id, false, "file_ref_invalid");
                        _engine.SendFile(dev, p.FileRef);
                        return Reply(cmd.Id, true);
                    }
                case "accept_offer":
                    {
                        var p = cmd.Payload.Deserialize<OfferPayload>() ?? new OfferPayload();
                        if (!Guid.TryParse(p.OfferId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        _engine.RespondToFileOffer(id, true);
                        return Reply(cmd.Id, true);
                    }
                case "reject_offer":
                    {
                        var p = cmd.Payload.Deserialize<OfferPayload>() ?? new OfferPayload();
                        if (!Guid.TryParse(p.OfferId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        _engine.RespondToFileOffer(id, false);
                        return Reply(cmd.Id, true);
                    }
                case "accept_pairing":
                    {
                        var p = cmd.Payload.Deserialize<PairingPayload>() ?? new PairingPayload();
                        if (!Guid.TryParse(p.PairingId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        _engine.RespondToPairing(id, p.Trust ? PairingDecision.Trust : PairingDecision.AllowOnce);
                        return Reply(cmd.Id, true);
                    }
                case "reject_pairing":
                    {
                        var p = cmd.Payload.Deserialize<PairingPayload>() ?? new PairingPayload();
                        if (!Guid.TryParse(p.PairingId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        _engine.RespondToPairing(id, PairingDecision.Reject);
                        return Reply(cmd.Id, true);
                    }
                case "clear_history":
                    _engine.ClearHistory();
                    return Reply(cmd.Id, true);
                case "delete_history_item":
                    {
                        var p = cmd.Payload.Deserialize<HistoryItemPayload>() ?? new HistoryItemPayload();
                        if (!Guid.TryParse(p.ItemId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        _engine.RemoveHistoryItem(id);
                        return Reply(cmd.Id, true);
                    }
                default:
                    return Reply(cmd.Id, false, "unknown_command");
            }
        }
        catch (Exception ex)
        {
            return Reply(cmd.Id, false, ex.Message);
        }
    }

    /// <summary>
    /// 把 engine 事件转成 protocol/companion-bridges.md §2 的 event JSON。
    /// </summary>
    public static string EncodeEvent(EngineEvent ev)
    {
        object? payload = ev switch
        {
            EngineEvent.DeviceAdded a => BridgeDevice.From(a.Device),
            EngineEvent.DeviceRemoved r => new { id = r.Id },
            EngineEvent.DeviceUpdated u => BridgeDevice.From(u.Device),
            EngineEvent.PairingPending p => BridgePairing.From(p.Pairing),
            EngineEvent.OfferPending o => BridgeOffer.From(o.Offer),
            EngineEvent.TransferProgress t => new { id = t.Id.ToString(), bytesSent = t.BytesSent, totalBytes = t.TotalBytes, speedBps = t.SpeedBps },
            EngineEvent.TransferDone t => new { id = t.Id.ToString(), ok = t.Ok, error = t.Error },
            EngineEvent.HistoryAdded h => BridgeHistory.From(h.Item),
            EngineEvent.ClipboardReceived c => BridgeClipboard.From(c.Entry),
            _ => null,
        };
        var type = ev switch
        {
            EngineEvent.DeviceAdded => "device_added",
            EngineEvent.DeviceRemoved => "device_removed",
            EngineEvent.DeviceUpdated => "device_updated",
            EngineEvent.PairingPending => "pairing_pending",
            EngineEvent.OfferPending => "offer_pending",
            EngineEvent.TransferProgress => "transfer_progress",
            EngineEvent.TransferDone => "transfer_done",
            EngineEvent.HistoryAdded => "history_added",
            EngineEvent.ClipboardReceived => "clipboard_received",
            _ => "unknown",
        };
        return JsonSerializer.Serialize(new
        {
            v = 1,
            id = "evt-" + Guid.NewGuid().ToString("N").Substring(0, 12),
            type,
            ts = DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            payload,
        });
    }

    private static string Reply(string id, bool ok, string? error = null, object? result = null)
    {
        return JsonSerializer.Serialize(new
        {
            v = 1,
            id,
            ok,
            error,
            result,
        });
    }

    private sealed class Cmd
    {
        [JsonPropertyName("v")] public int V { get; set; } = 1;
        [JsonPropertyName("id")] public string Id { get; set; } = "";
        [JsonPropertyName("type")] public string Type { get; set; } = "";
        [JsonPropertyName("ts")] public long Ts { get; set; }
        [JsonPropertyName("payload")] public JsonElement Payload { get; set; }
    }

    private sealed class SendTextPayload
    {
        [JsonPropertyName("peerId")] public string PeerId { get; set; } = "";
        [JsonPropertyName("text")] public string Text { get; set; } = "";
    }

    private sealed class SendClipboardPayload
    {
        [JsonPropertyName("peerId")] public string PeerId { get; set; } = "";
        [JsonPropertyName("content")] public string Content { get; set; } = "";
        [JsonPropertyName("kind")] public string Kind { get; set; } = "";
    }

    private sealed class SendFileRefPayload
    {
        [JsonPropertyName("peerId")] public string PeerId { get; set; } = "";
        [JsonPropertyName("fileRef")] public string FileRef { get; set; } = "";
        [JsonPropertyName("name")] public string Name { get; set; } = "";
        [JsonPropertyName("sizeBytes")] public long SizeBytes { get; set; }
        [JsonPropertyName("mime")] public string Mime { get; set; } = "";
    }

    private sealed class OfferPayload
    {
        [JsonPropertyName("offerId")] public string OfferId { get; set; } = "";
    }

    private sealed class PairingPayload
    {
        [JsonPropertyName("pairingId")] public string PairingId { get; set; } = "";
        [JsonPropertyName("trust")] public bool Trust { get; set; }
    }

    private sealed class HistoryItemPayload
    {
        [JsonPropertyName("itemId")] public string ItemId { get; set; } = "";
    }
}

internal sealed record BridgeDevice(string Id, string DisplayName, string Kind, string Model,
                                    string Ip, int RttMs, bool Online, bool Trusted, bool Busy)
{
    public static BridgeDevice From(Device d) => new(
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
        0, true, false, false);
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
                                     long? BytesTransferred, bool Ok, long CompletedAt)
{
    public static BridgeHistory From(HistoryItem h)
    {
        var dir = h.Direction == TransferDirection.Outgoing ? "sent" : "received";
        var ok = h.Status is TransferStatus.Completed;
        var completed = new DateTimeOffset(h.CreatedAt).ToUnixTimeSeconds();
        return h.Kind switch
        {
            HistoryKind.Text t => new(h.Id.ToString(), dir, h.Peer.Name, "text", t.Content, null, null, ok, completed),
            HistoryKind.File f => new(h.Id.ToString(), dir, h.Peer.Name, "file", null,
                new object[] { new { name = f.Name, sizeBytes = f.Size } },
                f.Size, ok, completed),
            _ => new(h.Id.ToString(), dir, h.Peer.Name, "text", null, null, null, ok, completed),
        };
    }
}

internal sealed record BridgeClipboard(string Id, string PeerName, string Kind, string Content, long Ts)
{
    public static BridgeClipboard From(ClipboardEntry e) => new(
        e.Id.ToString(), e.PeerName, e.Kind, e.Content,
        new DateTimeOffset(e.ReceivedAt).ToUnixTimeSeconds());
}
