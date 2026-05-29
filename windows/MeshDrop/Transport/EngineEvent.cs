using MeshDrop.Models;

namespace MeshDrop.Transport;

/// <summary>
/// 跨端 Companion-bridges 协议里的事件（B → A push）。Gateway 订阅 Engine.Event
/// 转发到 WebSocket 客户端。
/// </summary>
public abstract record EngineEvent
{
    public sealed record DeviceAdded(Device Device) : EngineEvent;
    public sealed record DeviceRemoved(string Id) : EngineEvent;
    public sealed record DeviceUpdated(Device Device) : EngineEvent;
    public sealed record PairingPending(PendingPairing Pairing) : EngineEvent;
    public sealed record OfferPending(PendingFileOffer Offer) : EngineEvent;
    public sealed record TransferProgress(System.Guid Id, long BytesSent, long TotalBytes, long SpeedBps) : EngineEvent;
    public sealed record TransferDone(System.Guid Id, bool Ok, string? Error) : EngineEvent;
    public sealed record HistoryAdded(HistoryItem Item) : EngineEvent;
    public sealed record ClipboardReceived(ClipboardEntry Entry) : EngineEvent;
}
