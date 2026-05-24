using System;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

public sealed partial class DiscoveryViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    public ObservableCollection<MockDevice> Devices { get; }

    [ObservableProperty] private string _selectedId = "";
    [ObservableProperty] private bool _isScanning;
    [ObservableProperty] private string? _lastError;

    public MockDevice? Selected => Devices.FirstOrDefault(d => d.Id == SelectedId);

    public string PeerCountText => $"附近设备 · Nearby · {Devices.Count} 台";

    public bool IsEmpty => Devices.Count == 0 && !IsScanning;

    public DiscoveryViewModel()
    {
        Devices = new ProjectedCollection<MeshDrop.Models.Device, MockDevice>(
            _engine.Devices, d => d.ToMock());
        Devices.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(PeerCountText));
            OnPropertyChanged(nameof(Selected));
            OnPropertyChanged(nameof(IsEmpty));
            if (Devices.Count > 0 && string.IsNullOrEmpty(SelectedId))
                SelectedId = Devices[0].Id;
        };

        IsScanning = _engine.IsStarting;
        LastError = _engine.LastError;
        _engine.PropertyChanged += OnEnginePropertyChanged;
    }

    private void OnEnginePropertyChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(ShareEngine.IsStarting):
                IsScanning = _engine.IsStarting;
                OnPropertyChanged(nameof(IsEmpty));
                break;
            case nameof(ShareEngine.LastError):
                LastError = _engine.LastError;
                break;
        }
    }

    partial void OnSelectedIdChanged(string value)
    {
        OnPropertyChanged(nameof(Selected));
    }
}
