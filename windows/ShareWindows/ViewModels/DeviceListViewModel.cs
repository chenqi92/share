using System;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Discovery;
using MeshDrop.Models;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;

namespace MeshDrop.ViewModels;

public partial class DeviceListViewModel : ObservableObject
{
    private readonly Identity _identity = Identity.LoadOrCreate();
    private readonly MdnsDiscovery _discovery;
    private readonly DispatcherQueue _dispatcher = DispatcherQueue.GetForCurrentThread();

    public ObservableCollection<DeviceVM> Devices { get; } = new();

    public string DisplayName { get; }
    public string FingerprintShort { get; }

    public Visibility EmptyStateVisibility =>
        Devices.Count == 0 ? Visibility.Visible : Visibility.Collapsed;

    public DeviceListViewModel()
    {
        DisplayName = Environment.MachineName;
        FingerprintShort = _identity.Fingerprint[..16];

        _discovery = new MdnsDiscovery(
            identity: _identity,
            displayName: DisplayName,
            model: WindowsModelString());
        _discovery.DevicesChanged += OnDevicesChanged;
    }

    public Task StartAsync() => _discovery.StartAsync();

    public void Stop() => _discovery.Stop();

    private void OnDevicesChanged(System.Collections.Generic.IReadOnlyList<Device> devices)
    {
        _dispatcher.TryEnqueue(() =>
        {
            Devices.Clear();
            foreach (var d in devices) Devices.Add(DeviceVM.From(d));
            OnPropertyChanged(nameof(EmptyStateVisibility));
        });
    }

    private static string WindowsModelString()
    {
        // 骨架：先返回静态值。TODO: 用 WMI (System.Management) 或 SetupDi 取真实型号。
        return "Windows PC";
    }
}
