using System.Collections.ObjectModel;
using System.Linq;
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
            if (_engine.IsStarting) return $"● {I18n.T("status.scanning")}";
            if (_engine.LastError is { } err) return $"● ERROR · {err}";
            if (!_engine.IsRunning) return $"● {I18n.T("status.offline")}";
            return $"● {I18n.T("status.online")} · {_engine.LocalIp} · {I18n.T("status.peersFormat", Devices.Count)}";
        }
    }

    public string UnreadChatCount => "0";

    public string NearbyCount => Devices.Count.ToString();
    public string SelfInitials => EngineProjection.Initials(_engine.DisplayName);
    public string SelfColor => EngineProjection.ColorFromId(_engine.Identity.Id);
    public string ActiveTransfersText => _engine.History.Count(h =>
        h.Status is MeshDrop.Models.TransferStatus.Transferring
            or MeshDrop.Models.TransferStatus.Pending
            or MeshDrop.Models.TransferStatus.WaitingApproval).ToString();

    public ShellViewModel()
    {
        Devices = new ProjectedCollection<MeshDrop.Models.Device, MockDevice>(
            _engine.Devices, d => d.ToMock());
        Devices.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(StatusText));
            OnPropertyChanged(nameof(NearbyCount));
        };
        _engine.History.CollectionChanged += (_, _) => OnPropertyChanged(nameof(ActiveTransfersText));
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
                    OnPropertyChanged(nameof(SelfInitials));
                    OnPropertyChanged(nameof(SelfColor));
                    break;
            }
        };
    }
}
