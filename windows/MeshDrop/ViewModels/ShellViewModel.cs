using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

public enum ShellSection { Discovery, Chat, Transfers, History, Clipboard, Trust, Settings }

public sealed partial class ShellViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    [ObservableProperty]
    private ShellSection _section = ShellSection.Discovery;

    [ObservableProperty]
    private string _selectedPeerId = "";

    public ObservableCollection<MockDevice> Devices { get; }

    public string SelfDisplayName => _engine.DisplayName;
    public string SelfIp => _engine.LocalIp;

    public string StatusText
    {
        get
        {
            if (_engine.IsStarting) return "● SCANNING · 扫描中…";
            if (_engine.LastError is { } err) return $"● ERROR · {err}";
            if (!_engine.IsRunning) return "● OFFLINE";
            return $"● ONLINE · {_engine.LocalIp} · {Devices.Count} peers";
        }
    }

    public string UnreadChatCount => "0";

    public ShellViewModel()
    {
        Devices = new ProjectedCollection<MeshDrop.Models.Device, MockDevice>(
            _engine.Devices, d => d.ToMock());
        Devices.CollectionChanged += (_, _) => OnPropertyChanged(nameof(StatusText));
        _engine.PropertyChanged += (_, e) =>
        {
            switch (e.PropertyName)
            {
                case nameof(ShareEngine.IsStarting):
                case nameof(ShareEngine.IsRunning):
                case nameof(ShareEngine.LastError):
                case nameof(ShareEngine.LocalIp):
                    OnPropertyChanged(nameof(StatusText));
                    OnPropertyChanged(nameof(SelfIp));
                    break;
                case nameof(ShareEngine.DisplayName):
                    OnPropertyChanged(nameof(SelfDisplayName));
                    break;
            }
        };
    }
}
