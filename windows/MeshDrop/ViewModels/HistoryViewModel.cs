using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;

namespace MeshDrop.ViewModels;

public sealed partial class HistoryViewModel : ObservableObject
{
    public ObservableCollection<MockHistory> Items { get; } = MockObs.History();
    public ObservableCollection<MockClipboard> Clipboard { get; } = MockObs.Clipboard();

    public string TodayLabel => "── TODAY · 今天 · 6 件 ──";
    public string YesterdayLabel => "── YESTERDAY · 昨天 · 12 件 ──";
}
