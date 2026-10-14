using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Makaretu.Dns;
using MeshDrop.Models;
using TXTRecord = MeshDrop.Models.TXTRecord;

namespace MeshDrop.Discovery;

/// <summary>Advertise and resolve MeshDrop on physical LAN interfaces.</summary>
public sealed class MdnsDiscovery : IDisposable
{
    private readonly Identity _identity;
    private string _displayName;
    private readonly string? _model;
    private readonly object _gate = new();
    private readonly MdnsDeviceCache _cache = new();
    private readonly Dictionary<string, DateTimeOffset> _queries = new();
    private IReadOnlyList<Device> _devices = Array.Empty<Device>();
    private ServiceDiscovery? _sd;
    private MulticastService? _mdns;
    private ServiceProfile? _profile;
    private CancellationTokenSource? _stop;

    public event Action<IReadOnlyList<Device>>? DevicesChanged;
    public MdnsDiscovery(Identity identity, string displayName, string? model)
    {
        _identity = identity;
        _displayName = displayName;
        _model = model;
    }

    public void Start(ushort port, string? displayName = null, bool advertise = true)
    {
        Dispose();
        if (!string.IsNullOrEmpty(displayName)) _displayName = displayName;
        var mdns = new MulticastService(NetworkInterfaceSelector.FilterPreferred);
        _mdns = mdns;
        _sd = new ServiceDiscovery(mdns);
        mdns.AnswerReceived += OnAnswer;
        mdns.NetworkInterfaceDiscovered += (_, _) => Refresh(mdns, announce: true);
        if (advertise)
        {
            // Default ServiceProfile addresses include VPNs even when sockets are filtered.
            _profile = new ServiceProfile(_identity.Id, TXTRecord.ServiceType, port,
                NetworkInterfaceSelector.GetPreferredIPv4Addresses());
            foreach (var (key, value) in TXTRecord.Encode(_identity, _displayName, DeviceOS.Windows, _model, port))
                _profile.AddProperty(key, value);
            _sd.Advertise(_profile);
        }
        mdns.Start();
        _stop = new CancellationTokenSource();
        _ = BrowseAsync(mdns, _stop.Token);
    }

    private async Task BrowseAsync(MulticastService mdns, CancellationToken token)
    {
        var delay = 2;
        try
        {
            while (!token.IsCancellationRequested)
            {
                await Task.Delay(TimeSpan.FromSeconds(delay), token).ConfigureAwait(false);
                Refresh(mdns, announce: false);
                delay = Math.Min(delay * 2, 30);
            }
        }
        catch (OperationCanceledException) { }
    }

    private void Refresh(MulticastService mdns, bool announce)
    {
        lock (_gate)
        {
            if (!ReferenceEquals(mdns, _mdns)) return;
            try
            {
                if (announce && _profile is not null) _sd?.Announce(_profile);
                _sd?.QueryUnicastServiceInstances(TXTRecord.ServiceType);
                Publish(DateTimeOffset.UtcNow);
            }
            catch (Exception ex) when (ex is ObjectDisposedException or System.Net.Sockets.SocketException or InvalidOperationException)
            { System.Diagnostics.Debug.WriteLine($"mDNS refresh: {ex.Message}"); }
        }
    }

    private void OnAnswer(object? sender, MessageEventArgs e)
    {
        lock (_gate)
        {
            if (!ReferenceEquals(sender, _mdns)) return;
            var now = DateTimeOffset.UtcNow;
            _cache.Update(e.Message, e.RemoteEndPoint, now);
            Publish(now);
            foreach (var key in _queries.Where(kv => now - kv.Value > TimeSpan.FromSeconds(30)).Select(kv => kv.Key).ToArray())
                _queries.Remove(key);
            foreach (var (name, type) in _cache.MissingQuestions().ToArray())
            {
                var key = $"{name}|{type}";
                if (_queries.TryGetValue(key, out var last) && now - last < TimeSpan.FromSeconds(2)) continue;
                _queries[key] = now;
                _mdns?.SendUnicastQuery(name, type: type);
            }
        }
    }

    private void Publish(DateTimeOffset now)
    {
        var devices = _cache.Snapshot(_identity.Id, now);
        if (_devices.SequenceEqual(devices)) return;
        _devices = devices;
        DevicesChanged?.Invoke(devices);
    }

    public void Stop() => Dispose();
    public void Dispose()
    {
        lock (_gate)
        {
            var mdns = _mdns;
            _mdns = null;
            _stop?.Cancel();
            _stop?.Dispose();
            _stop = null;
            _sd?.Dispose();
            _sd = null;
            mdns?.Dispose();
            _profile = null;
            _cache.Clear();
            _queries.Clear();
            _devices = Array.Empty<Device>();
            DevicesChanged?.Invoke(_devices);
        }
    }
}
