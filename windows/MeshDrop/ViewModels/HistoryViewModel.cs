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

    // 剪贴板历史：实时投影引擎收到的 ClipboardInbox（最新在前，引擎已在 UI 线程维护）。
    public ObservableCollection<MockClipboard> Clipboard { get; }

    public string TodayLabel => $"── 历史 · HISTORY · {Items.Count} 件 ──";
    public string YesterdayLabel => "── 早些时候 · EARLIER ──";
    public string ClipboardLabel => $"── 剪贴板 · CLIPBOARD · {Clipboard.Count} ──";

    public HistoryViewModel()
    {
        Items = new ProjectedCollection<HistoryItem, MockHistory>(
            _engine.History, h => h.ToMock());
        Items.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(TodayLabel));
        };

        Clipboard = new ProjectedCollection<ClipboardEntry, MockClipboard>(
            _engine.ClipboardInbox, e => e.ToMock());
        Clipboard.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(ClipboardLabel));
        };
    }
}
