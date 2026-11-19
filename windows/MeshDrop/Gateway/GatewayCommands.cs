using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;
using MeshDrop.Models;
using MeshDrop.Transport;
using static MeshDrop.Gateway.GatewayWire;

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
                    return Reply(cmd.Id, true, null, new { devices = _engine.Devices.Select(DeviceWire).ToArray() });
                case "get_state":
                    return Reply(cmd.Id, true, null, Snapshot());
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
                        if (!GatewayUpload.IsUpload(p.FileRef))
                            return Reply(cmd.Id, false, "file_ref_invalid");
                        _engine.SendFile(dev, p.FileRef!);
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
                    var scope = cmd.Payload.ValueKind == JsonValueKind.Object && cmd.Payload.TryGetProperty("scope", out var value)
                        ? value.GetString() : "all";
                    if (scope == "all") _engine.ClearHistory();
                    else if (scope is "sent" or "received")
                    {
                        var direction = scope == "sent" ? TransferDirection.Outgoing : TransferDirection.Incoming;
                        foreach (var item in _engine.History.Where(h => h.Direction == direction).ToArray())
                            _engine.RemoveHistoryItem(item.Id);
                    }
                    else return Reply(cmd.Id, false, "bad_scope");
                    return Reply(cmd.Id, true);
                case "delete_history_item":
                    {
                        var p = cmd.Payload.Deserialize<HistoryItemPayload>() ?? new HistoryItemPayload();
                        if (!Guid.TryParse(p.ItemId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        _engine.RemoveHistoryItem(id);
                        return Reply(cmd.Id, true);
                    }
                case "cancel_transfer":
                    {
                        var p = cmd.Payload.Deserialize<HistoryItemPayload>() ?? new HistoryItemPayload();
                        if (!Guid.TryParse(p.ItemId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        _engine.CancelTransfer(id);
                        return Reply(cmd.Id, true);
                    }
                case "retry_transfer":
                    {
                        var p = cmd.Payload.Deserialize<HistoryItemPayload>() ?? new HistoryItemPayload();
                        if (!Guid.TryParse(p.ItemId, out var id)) return Reply(cmd.Id, false, "bad_id");
                        return _engine.RetryTransfer(id)
                            ? Reply(cmd.Id, true)
                            : Reply(cmd.Id, false, "retry_unavailable");
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

    private BridgeDevice DeviceWire(Device d) => BridgeDevice.From(d,
        _engine.Trusted.Any(t => t.Fingerprint == d.Fingerprint),
        _engine.History.Any(h => h.Peer.Id == d.Id && h.Status is TransferStatus.Transferring));

    private object Snapshot() => new
    {
        self = DeviceWire(_engine.SelfDevice),
        me = new { displayName = _engine.DisplayName, fingerprint = _engine.Identity.Fingerprint, ip = _engine.LocalIp, hostIp = _engine.LocalIp },
        devices = _engine.Devices.Select(DeviceWire).ToArray(),
        history = _engine.History.Select(BridgeHistory.From).ToArray(),
        pendingPairings = _engine.PendingPairings.Select(BridgePairing.From).ToArray(),
        pendingOffers = _engine.PendingFileOffers.Select(BridgeOffer.From).ToArray(),
    };

    internal string DeviceSnapshot() => Event("device_snapshot", _engine.Devices.Select(DeviceWire).ToArray());

    internal string InitialSnapshot() => Event("state_snapshot", Snapshot());

    /// <summary>
    /// 把 engine 事件转成 protocol/companion-bridges.md §2 的 event JSON。
    /// </summary>
    public string EncodeEvent(EngineEvent ev)
    {
        object? payload = ev switch
        {
            EngineEvent.DeviceAdded a => DeviceWire(a.Device),
            EngineEvent.DeviceRemoved r => new { id = r.Id },
            EngineEvent.DeviceUpdated u => DeviceWire(u.Device),
            EngineEvent.PairingPending p => BridgePairing.From(p.Pairing),
            EngineEvent.OfferPending o => BridgeOffer.From(o.Offer),
            EngineEvent.TransferProgress t => Progress(t),
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
        return Event(type, payload);
    }

    private object Progress(EngineEvent.TransferProgress t)
    {
        var item = _engine.History.FirstOrDefault(h => h.Id == t.Id);
        return new { id = t.Id, peerName = item?.Peer.Name, fileName = (item?.Kind as HistoryKind.File)?.Name,
            bytesSent = t.BytesSent, totalBytes = t.TotalBytes, speedBps = t.SpeedBps };
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
