using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;

namespace MeshDrop.ViewModels;

public sealed partial class TransfersViewModel : ObservableObject
{
    public ObservableCollection<MockTransfer> All { get; } = MockObs.Transfers();

    [ObservableProperty]
    private string _filter = "all";  // all | active | done

    public int ActiveCount =>
        All.Count(t => t.State == MockTransferState.Sending || t.State == MockTransferState.Receiving);

    public int DoneCount => All.Count(t => t.State == MockTransferState.Done);

    public int[] UploadBars => MockData.UploadBars;
    public int[] DownloadBars => MockData.DownloadBars;
    public int[] SessionBars => MockData.SessionBars;

    public string SessionValue => "2.41 GB";
    public string UpValue => "8.4 MB/s";
    public string DownValue => "11.7 MB/s";
}
