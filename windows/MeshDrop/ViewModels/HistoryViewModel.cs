using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;
using MeshDrop.Models;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

public sealed partial class HistoryViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    public ObservableCollection<MockHistory> Items { get; }

    // 剪贴板尚未实现，空集合即可
    public ObservableCollection<MockClipboard> Clipboard { get; } = new();

    public string TodayLabel => $"── 历史 · HISTORY · {Items.Count} 件 ──";
    public string YesterdayLabel => "── 早些时候 · EARLIER ──";

    public HistoryViewModel()
    {
        Items = new ProjectedCollection<HistoryItem, MockHistory>(
            _engine.History, h => h.ToMock());
        Items.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(TodayLabel));
        };
    }
}
