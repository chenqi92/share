using System;

namespace MeshDrop.Models;

public sealed record PendingPairing(Guid Id, Device Peer, DateTime ReceivedAt)
{
    public static PendingPairing Create(Device peer) => new(Guid.NewGuid(), peer, DateTime.Now);
}

public enum PairingDecision { Reject, AllowOnce, Trust }
