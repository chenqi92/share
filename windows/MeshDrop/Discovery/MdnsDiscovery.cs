using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using Makaretu.Dns;
using MeshDrop.Models;
// 项目内 TXTRecord 与 Makaretu.Dns.TXTRecord 同名歧义；显式别名指向我们自己的版本
using TXTRecord = MeshDrop.Models.TXTRecord;

namespace MeshDrop.Discovery;

/// <summary>
/// 只管 mDNS 注册 + browse；TCP listener 由 ShareEngine 持有，端口由外部传入。
/// 解析得到的 IP 透传到 Device.Host。
/// </summary>
public sealed class MdnsDiscovery : IDisposable
{
    private readonly Identity _identity;
    private string _displayName;
    private readonly string? _model;

    private ServiceDiscovery? _sd;
    private readonly ConcurrentDictionary<string, Device> _devices = new();

    public event Action<IReadOnlyList<Device>>? DevicesChanged;

    public MdnsDiscovery(Identity identity, string displayName, string? model)
    {
        _identity = identity;
        _displayName = displayName;
        _model = model;
    }

    public void Start(ushort port, string? displayName = null)
    {
        if (!string.IsNullOrEmpty(displayName)) _displayName = displayName;

        _sd = new ServiceDiscovery();
        _sd.ServiceInstanceDiscovered += OnInstanceDiscovered;
        _sd.ServiceInstanceShutdown += OnInstanceShutdown;

        var profile = new ServiceProfile(
            instanceName: _identity.Id,
            serviceName: TXTRecord.ServiceType,
            port: port);
        foreach (var (k, v) in TXTRecord.Encode(_identity, _displayName, DeviceOS.Windows, _model, port))
            profile.AddProperty(k, v);

        _sd.Advertise(profile);
        _sd.Announce(profile);
        _sd.QueryServiceInstances(TXTRecord.ServiceType);
    }

    public void Stop() => Dispose();

    public void Dispose()
    {
        _sd?.Dispose();
        _sd = null;
        _devices.Clear();
        Notify();
    }

    private void OnInstanceDiscovered(object? sender, ServiceInstanceDiscoveryEventArgs e)
    {
        var attrs = new Dictionary<string, string>(StringComparer.Ordinal);
        string? host = null;
        foreach (var record in e.Message.AdditionalRecords)
        {
            switch (record)
            {
                case TXTRecord txt when txt.Name.ToCanonical().Equals(e.ServiceInstanceName.ToCanonical()):
                    foreach (var s in txt.Strings)
                    {
                        var idx = s.IndexOf('=');
                        if (idx > 0) attrs[s.Substring(0, idx)] = s.Substring(idx + 1);
                    }
                    break;
                case ARecord a when host is null:
                    host = a.Address.ToString();
                    break;
                case AAAARecord aaaa when host is null:
                    host = aaaa.Address.ToString();
                    break;
            }
        }
        if (attrs.Count == 0) return;

        var device = TXTRecord.Decode(attrs);
        if (device is null) return;
        if (device.Id == _identity.Id) return;

        _devices[device.Id] = device with { Host = host };
        Notify();
    }

    private void OnInstanceShutdown(object? sender, ServiceInstanceShutdownEventArgs e)
    {
        var instance = e.ServiceInstanceName.Labels[0];
        if (_devices.TryRemove(instance, out _)) Notify();
    }

    private void Notify()
    {
        var list = new List<Device>(_devices.Values);
        list.Sort((a, b) => string.Compare(a.Name, b.Name, StringComparison.Ordinal));
        DevicesChanged?.Invoke(list);
    }
}
