using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;

namespace MeshDrop.ViewModels;

public enum ShellSection { Discovery, Chat, Transfers, History, Trust, Settings }

public sealed partial class ShellViewModel : ObservableObject
{
    [ObservableProperty]
    private ShellSection _section = ShellSection.Discovery;

    [ObservableProperty]
    private string _selectedPeerId = "lily";

    public ObservableCollection<MockDevice> Devices { get; } = MockObs.Devices();
    public MockMe Me { get; } = MockData.Me;

    public string StatusText =>
        $"● ONLINE · {Me.Lan} · {Me.Ip} · {Devices.Count} peers · ↑ 8.4 MB/s · ↓ 11.7 MB/s · 1.24 GB";

    public string UnreadChatCount => "2";
}
