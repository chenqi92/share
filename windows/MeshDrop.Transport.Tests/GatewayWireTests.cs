using System.Text.Json;
using MeshDrop.Gateway;
using MeshDrop.Models;
using Xunit;

namespace MeshDrop.Transport.Tests;

public class GatewayWireTests
{
    private static readonly Device Peer = new("peer", "Nearby", DeviceOS.Android, "Phone", "0123456789abcdef", 1234);

    [Fact]
    public void SnapshotAndRepliesUseBrowserFieldNamesAtEveryLevel()
    {
        var payload = new { devices = new[] { BridgeDevice.From(Peer, true, false) } };
        using var evt = JsonDocument.Parse(GatewayWire.Event("state_snapshot", payload));
        Assert.Equal("state_snapshot", evt.RootElement.GetProperty("type").GetString());
        using var reply = JsonDocument.Parse(GatewayWire.Reply("cmd1", true, result: payload));
        foreach (var state in new[] { evt.RootElement.GetProperty("payload"), reply.RootElement.GetProperty("result") })
        {
            var device = state.GetProperty("devices")[0];
            Assert.Equal("Nearby", device.GetProperty("displayName").GetString());
            Assert.Equal("peer", device.GetProperty("id").GetString());
            Assert.True(device.GetProperty("trusted").GetBoolean());
        }
    }

    [Fact]
    public void IncomingFileReportsActualProgressAndVerifiedCompletion()
    {
        var item = HistoryItem.Create(Peer, TransferDirection.Incoming,
            new HistoryKind.File("收件.bin", 120, "local"), new TransferStatus.Transferring(37, 120));
        var progress = BridgeHistory.From(item);
        Assert.Equal("receiving", progress.Status);
        Assert.Equal(37, progress.BytesTransferred);
        Assert.False(progress.Ok);
        var completed = BridgeHistory.From(item.WithStatus(new TransferStatus.Completed()));
        Assert.Equal("done", completed.Status);
        Assert.Equal(120, completed.BytesTransferred);
        Assert.True(completed.Ok);
        var failed = BridgeHistory.From(item.WithStatus(new TransferStatus.Failed("checksum")));
        Assert.Equal("failed", failed.Status);
        Assert.Equal("checksum", failed.Error);
        Assert.Null(failed.BytesTransferred);
    }
}
