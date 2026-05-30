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

    // 速度柱状图序列：引擎每秒采样的吞吐 → 取整。x:Bind 需 Mode=OneWay 才会随更新刷新。
    // 类型用 IReadOnlyList<int>（不是 int[]）—— WinUI 3 x:Bind 编译器在 DashTile.Bars
    // (IReadOnlyList<int>) DependencyProperty 上拒绝 int[] 直接绑定（WMC1121）
    [ObservableProperty] private IReadOnlyList<int> _uploadBars = new int[14];
    [ObservableProperty] private IReadOnlyList<int> _downloadBars = new int[14];
    [ObservableProperty] private IReadOnlyList<int> _sessionBars = new int[14];

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
        _engine.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(ShareEngine.ThroughputUp) or nameof(ShareEngine.ThroughputDown))
            {
                RefreshBars();
            }
        };
    }

    private void RefreshBars()
    {
        var up = _engine.ThroughputUp;
        var down = _engine.ThroughputDown;
        if (up.Count == 0 && down.Count == 0) return;
        UploadBars = up.Select(ToBar).ToArray();
        DownloadBars = down.Select(ToBar).ToArray();
        int n = Math.Max(up.Count, down.Count);
        SessionBars = Enumerable.Range(0, n)
            .Select(i => ToBar((i < up.Count ? up[i] : 0) + (i < down.Count ? down[i] : 0)))
            .ToArray();

        static int ToBar(double v) => (int)Math.Min(Math.Round(v), int.MaxValue);
    }
}
