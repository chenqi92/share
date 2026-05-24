using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;

namespace MeshDrop.ViewModels;

public sealed partial class DiscoveryViewModel : ObservableObject
{
    public ObservableCollection<MockDevice> Devices { get; } = MockObs.Devices();
    public MockMe Me { get; } = MockData.Me;

    [ObservableProperty]
    private string _selectedId = "lily";

    public MockDevice? Selected => Devices.FirstOrDefault(d => d.Id == SelectedId);

    public string PeerCountText => $"附近设备 · Nearby · {Devices.Count} 台";

    partial void OnSelectedIdChanged(string value)
    {
        OnPropertyChanged(nameof(Selected));
    }
}
