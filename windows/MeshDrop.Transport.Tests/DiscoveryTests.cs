using System.Net;
using Makaretu.Dns;
using MeshDrop.Discovery;
using Xunit;

namespace MeshDrop.Transport.Tests;

public class DiscoveryTests
{
    private static readonly DateTimeOffset Now = DateTimeOffset.UtcNow;
    private static readonly IPEndPoint Remote = new(IPAddress.Parse("192.168.1.20"), 5353);
    private const string Id = "11111111111111111111111111111111";
    private const string Instance = Id + "._meshdrop._tcp.local";
    private const string Host = "iphone.local";
    private static ResourceRecord[] PeerRecords() =>
    [
        new PTRRecord { Name = "_meshdrop._tcp.local", DomainName = Instance, TTL = TimeSpan.FromSeconds(90) },
        new SRVRecord { Name = Instance, Target = Host, Port = 5000, TTL = TimeSpan.FromSeconds(90) },
        new TXTRecord { Name = Instance, TTL = TimeSpan.FromSeconds(90), Strings =
            { "v=1", "id=" + Id, "name=aVBob25l", "os=ios", "fp=" + Id, "port=5000" } },
        new AAAARecord { Name = Host, Address = IPAddress.Parse("fe80::1234"), TTL = TimeSpan.FromSeconds(90) },
        new ARecord { Name = Host, Address = Remote.Address, TTL = TimeSpan.FromSeconds(90) }
    ];
    private static Message Answer(params ResourceRecord[] records)
    {
        var message = new Message();
        foreach (var record in records) message.Answers.Add(record);
        return message;
    }

    [Fact]
    public void SplitBonjourAnswersResolveSrvTargetAndPreferIPv4()
    {
        var cache = new MdnsDeviceCache();
        var records = PeerRecords();
        cache.Update(Answer(records[0]), Remote, Now);
        Assert.Empty(cache.Snapshot("self", Now));
        Assert.Contains(cache.MissingQuestions(), q => q.Type == DnsType.SRV);
        // An unrelated host must not become the peer endpoint.
        cache.Update(Answer(new ARecord { Name = "unrelated.local", Address = IPAddress.Parse("10.0.0.9") }), Remote, Now);
        foreach (var record in records.Skip(1)) cache.Update(Answer(record), Remote, Now);
        var peer = Assert.Single(cache.Snapshot("self", Now));
        Assert.Equal("192.168.1.20", peer.Host);
        Assert.Equal("iPhone", peer.Name);
        Assert.Empty(cache.MissingQuestions());
    }

    [Fact]
    public void AdditionalRecordsAndMultipleInstancesRemainIndependent()
    {
        var cache = new MdnsDeviceCache();
        var records = PeerRecords();
        var message = Answer(records[0]);
        foreach (var r in records.Skip(1)) message.AdditionalRecords.Add(r);
        message.Answers.Add(new PTRRecord { Name = "_other._tcp.local", DomainName = "ignored._other._tcp.local" });
        cache.Update(message, Remote, Now);
        Assert.Single(cache.Snapshot("self", Now));
        Assert.Empty(cache.Snapshot(Id, Now));
    }

    [Fact]
    public void GoodbyeAndExpirationRemovePeer()
    {
        var cache = new MdnsDeviceCache();
        cache.Update(Answer(PeerRecords()), Remote, Now);
        Assert.Single(cache.Snapshot("self", Now));
        cache.Update(Answer(new PTRRecord { Name = "_meshdrop._tcp.local", DomainName = Instance, TTL = TimeSpan.Zero }), Remote, Now);
        Assert.Empty(cache.Snapshot("self", Now));
        cache.Update(Answer(PeerRecords()), Remote, Now);
        Assert.Empty(cache.Snapshot("self", Now.AddSeconds(91)));
    }

    [Fact]
    public void LinkLocalIPv6RequiresScope()
    {
        var records = PeerRecords().Where(r => r is not ARecord).ToArray();
        var cache = new MdnsDeviceCache();
        cache.Update(Answer(records), Remote, Now);
        Assert.Empty(cache.Snapshot("self", Now));
        cache.Update(Answer(records), new IPEndPoint(IPAddress.Parse("fe80::5678%7"), 5353), Now);
        Assert.Equal("fe80::1234%7", Assert.Single(cache.Snapshot("self", Now)).Host);
    }

    [Fact]
    public void PortMismatchDoesNotPublishPeer()
    {
        var records = PeerRecords();
        ((SRVRecord)records[1]).Port = 9999;
        var cache = new MdnsDeviceCache();
        cache.Update(Answer(records), Remote, Now);
        Assert.Empty(cache.Snapshot("self", Now));
    }
}
