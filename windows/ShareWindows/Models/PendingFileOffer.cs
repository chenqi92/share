using System;

namespace MeshDrop.Models;

public sealed record PendingFileOffer(
    Guid Id,                  // = transfer_id
    Device Peer,
    string FileName,
    long FileSize,
    string Sha256,
    DateTime ReceivedAt)
{
    public string FormattedSize => ByteFormat.Format(FileSize);
}
