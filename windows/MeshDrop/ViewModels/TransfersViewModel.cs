using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MeshDrop.Mock;
using MeshDrop.Models;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

public sealed partial class TransfersViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    public ObservableCollection<MockTransfer> All { get; }

    /// <summary>
    /// 用户点 Cancel：MockTransfer.Id 是 history Guid 字符串，解出后转给 ShareEngine.CancelTransfer。
    /// </summary>
    [RelayCommand]
    private void Cancel(MockTransfer item)
    {
        if (Guid.TryParse(item.Id, out var hid))
        {
            _engine.CancelTransfer(hid);
        }
    }

    [ObservableProperty]
    private string _filter = "all";  // all | active | done

    public int ActiveCount =>
        All.Count(t => t.State == MockTransferState.Sending || t.State == MockTransferState.Receiving);

    public int DoneCount => All.Count(t => t.State == MockTransferState.Done);

    // Throughput / 24h 实时统计骨架：v0.1 没历史聚合，先给 0 占位（UI 视觉不动）。
    // 类型用 IReadOnlyList<int>（不是 int[]）—— WinUI 3 x:Bind 编译器在 DashTile.Bars
    // (IReadOnlyList<int>) DependencyProperty 上拒绝 int[] 直接绑定（WMC1121）
    public IReadOnlyList<int> UploadBars { get; } = new int[14];
    public IReadOnlyList<int> DownloadBars { get; } = new int[14];
    public IReadOnlyList<int> SessionBars { get; } = new int[15];

    public string SessionValue => "—";
    public string UpValue => "—";
    public string DownValue => "—";

    public TransfersViewModel()
    {
        All = new ProjectedCollection<HistoryItem, MockTransfer>(
            _engine.History, h => h.ToTransfer());
        All.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(ActiveCount));
            OnPropertyChanged(nameof(DoneCount));
        };
    }
}
