using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Threading.Tasks;
using MeshDrop.Models;
using Makaretu.Dns;

namespace MeshDrop.Discovery;

/// <summary>
/// 同网段设备发现。同时承担 responder（广告本机）与 querier（浏览其他端）。
/// </summary>
public sealed class MdnsDiscovery : IDisposable
{
    private readonly Identity _identity;
    private readonly string _displayName;
    private readonly string? _model;

    private ServiceDiscovery? _sd;
    private TcpListener? _listener;
    private CancellationTokenSource? _cts;

    private readonly ConcurrentDictionary<string, Device> _devices = new();

    public event Action<IReadOnlyList<Device>>? DevicesChanged;

    public MdnsDiscovery(Identity identity, string displayName, string? model)
    {
        _identity = identity;
        _displayName = displayName;
        _model = model;
    }

    public Task StartAsync()
    {
        // 让系统分配端口
        _listener = new TcpListener(IPAddress.Any, 0);
        _listener.Start();
        var port = (ushort)((IPEndPoint)_listener.LocalEndpoint).Port;

        _cts = new CancellationTokenSource();
        _ = AcceptLoopAsync(_cts.Token);   // 骨架：accept 后直接关

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

        return Task.CompletedTask;
    }

    public void Stop() => Dispose();

    public void Dispose()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;

        _sd?.Dispose();
        _sd = null;

        _listener?.Stop();
        _listener = null;
    }

    private async Task AcceptLoopAsync(CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested && _listener != null)
            {
                var client = await _listener.AcceptTcpClientAsync(ct);
                // 骨架：关闭。TODO：接入 Frame 读写循环。
                client.Close();
            }
        }
        catch (OperationCanceledException) { }
        catch (ObjectDisposedException) { }
    }

    private void OnInstanceDiscovered(object? sender, ServiceInstanceDiscoveryEventArgs e)
    {
        // 解析 TXT
        var attrs = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var record in e.Message.AdditionalRecords)
        {
            if (record is TXTRecord txt && txt.Name.ToCanonical().Equals(e.ServiceInstanceName.ToCanonical()))
            {
                foreach (var s in txt.Strings)
                {
                    var idx = s.IndexOf('=');
                    if (idx > 0) attrs[s.Substring(0, idx)] = s.Substring(idx + 1);
                }
            }
        }
        if (attrs.Count == 0) return;

        var device = TXTRecord.Decode(attrs);
        if (device is null) return;
        if (device.Id == _identity.Id) return;  // 自己

        _devices[device.Id] = device;
        Notify();
    }

    private void OnInstanceShutdown(object? sender, ServiceInstanceShutdownEventArgs e)
    {
        var instance = e.ServiceInstanceName.Labels[0];
        _devices.TryRemove(instance, out _);
        Notify();
    }

    private void Notify()
    {
        var list = new List<Device>(_devices.Values);
        list.Sort((a, b) => string.Compare(a.Name, b.Name, StringComparison.Ordinal));
        DevicesChanged?.Invoke(list);
    }
}
