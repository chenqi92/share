using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using Makaretu.Dns;
using MeshDrop.Models;
using DeviceTxt = MeshDrop.Models.TXTRecord;

namespace MeshDrop.Discovery;

// Bonjour may send PTR, SRV, TXT and addresses in separate packets/answer sections.
internal sealed class MdnsDeviceCache
{
    private readonly Dictionary<string, Entry> _records = new(StringComparer.Ordinal);
    private static readonly DomainName Service = "_meshdrop._tcp.local";
    private sealed record Entry(ResourceRecord[] Records, DateTimeOffset Expires, long ScopeId);

    public void Update(Message message, IPEndPoint remote, DateTimeOffset now)
    {
        Expire(now);
        foreach (var group in message.Answers.Concat(message.AdditionalRecords)
                     .Where(r => r is PTRRecord or SRVRecord or Makaretu.Dns.TXTRecord or AddressRecord)
                     .GroupBy(Key))
        {
            var live = group.Where(r => r.TTL > TimeSpan.Zero).ToArray();
            if (live.Length == 0) { _records.Remove(group.Key); continue; }
            if (_records.Count >= 1024 && !_records.ContainsKey(group.Key)) continue;
            var ttl = live.Min(r => r.TTL.TotalSeconds);
            var scope = remote.Address.AddressFamily == AddressFamily.InterNetworkV6
                ? remote.Address.ScopeId : 0;
            _records[group.Key] = new Entry(live, now.AddSeconds(Math.Min(ttl, 120)), scope);
        }
    }

    public IReadOnlyList<Device> Snapshot(string selfId, DateTimeOffset now)
    {
        Expire(now);
        var result = new Dictionary<string, Device>(StringComparer.Ordinal);
        foreach (var ptr in Records<PTRRecord>().Where(p => p.Name.Equals(Service)))
        {
            var srv = Records<SRVRecord>().FirstOrDefault(r => r.Name.Equals(ptr.DomainName));
            var txt = Records<Makaretu.Dns.TXTRecord>().FirstOrDefault(r => r.Name.Equals(ptr.DomainName));
            if (srv is null || txt is null) continue;
            var attrs = new Dictionary<string, string>(StringComparer.Ordinal);
            foreach (var value in txt.Strings)
            {
                var split = value.IndexOf('=');
                if (split > 0) attrs[value[..split]] = value[(split + 1)..];
            }
            var device = DeviceTxt.Decode(attrs);
            if (device is null || device.Id == selfId || device.Port != srv.Port) continue;
            var address = _records.Values.SelectMany(entry => entry.Records.OfType<AddressRecord>()
                    .Where(r => r.Name.Equals(srv.Target))
                    .Select(r => WithScope(r.Address, entry.ScopeId)))
                .Where(a => a is not null && !IPAddress.IsLoopback(a)
                    && !a.Equals(IPAddress.Any) && !a.Equals(IPAddress.IPv6Any))
                .OrderBy(a => a!.AddressFamily == AddressFamily.InterNetwork ? 0 : 1)
                .FirstOrDefault();
            if (address is not null) result[device.Id] = device with { Host = address.ToString() };
        }
        return result.Values.OrderBy(d => d.Name, StringComparer.Ordinal).ToArray();
    }

    public IEnumerable<(DomainName Name, DnsType Type)> MissingQuestions()
    {
        foreach (var ptr in Records<PTRRecord>().Where(p => p.Name.Equals(Service)))
        {
            var srv = Records<SRVRecord>().FirstOrDefault(r => r.Name.Equals(ptr.DomainName));
            if (srv is null) yield return (ptr.DomainName, DnsType.SRV);
            if (!Records<Makaretu.Dns.TXTRecord>().Any(r => r.Name.Equals(ptr.DomainName)))
                yield return (ptr.DomainName, DnsType.TXT);
            if (srv is not null && !Records<AddressRecord>().Any(r => r.Name.Equals(srv.Target)))
            {
                yield return (srv.Target, DnsType.A);
                yield return (srv.Target, DnsType.AAAA);
            }
        }
    }

    public void Clear() => _records.Clear();
    private IEnumerable<T> Records<T>() where T : ResourceRecord =>
        _records.Values.SelectMany(e => e.Records).OfType<T>();
    private static string Key(ResourceRecord record) => record is PTRRecord ptr
        ? $"{ptr.Name.ToCanonical()}|PTR|{ptr.DomainName.ToCanonical()}"
        : $"{record.Name.ToCanonical()}|{record.Type}";
    private void Expire(DateTimeOffset now)
    {
        foreach (var key in _records.Where(kv => kv.Value.Expires <= now).Select(kv => kv.Key).ToArray())
            _records.Remove(key);
    }
    private static IPAddress? WithScope(IPAddress address, long scope)
    {
        if (!address.IsIPv6LinkLocal) return address;
        if (address.ScopeId != 0) return address;
        return scope == 0 ? null : new IPAddress(address.GetAddressBytes(), scope);
    }
}
