using System.Collections.ObjectModel;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MeshDrop.Mock;
using MeshDrop.Models;
using MeshDrop.Transport;
using Windows.ApplicationModel.DataTransfer;

namespace MeshDrop.ViewModels;

/// <summary>
/// 剪贴板页 VM：把一段文字显式推给选中设备 + 展示收到的 ClipboardInbox。
/// 见 protocol/messages.md §0x11 —— 由用户点一下才发，不是后台静默同步。
/// </summary>
public sealed partial class ClipboardViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    /// 收到的剪贴板（引擎在 UI 线程插入，直接绑定即可）。
    public ObservableCollection<ClipboardEntry> Inbox => _engine.ClipboardInbox;

    /// 设备选择器数据源。
    public ObservableCollection<MockDevice> Devices { get; }

    [ObservableProperty]
    private string _selectedDeviceId = "";

    [ObservableProperty]
    private string _draft = "";

    public string InboxLabel => $"── INBOX · 收到的剪贴板 · {Inbox.Count} ──";

    public ClipboardViewModel()
    {
        Devices = new ProjectedCollection<MeshDrop.Models.Device, MockDevice>(
            _engine.Devices, d => d.ToMock());
        if (_engine.Devices.FirstOrDefault() is { } first) SelectedDeviceId = first.Id;
        Inbox.CollectionChanged += (_, _) => OnPropertyChanged(nameof(InboxLabel));
    }

    /// 读取系统剪贴板文本填入编辑器。
    [RelayCommand]
    private async Task ReadSystemClipboardAsync()
    {
        try
        {
            var view = Clipboard.GetContent();
            if (view.Contains(StandardDataFormats.Text))
            {
                Draft = await view.GetTextAsync();
            }
            else if (view.Contains(StandardDataFormats.WebLink))
            {
                Draft = (await view.GetWebLinkAsync())?.ToString() ?? Draft;
            }
        }
        catch
        {
            // 剪贴板访问可能 race / 无权限，静默忽略
        }
    }

    /// 推送：取选中设备（无选中时退回第一台），按内容判定 kind。
    [RelayCommand]
    private void Push()
    {
        var content = (Draft ?? "").Trim();
        if (content.Length == 0) return;
        var dev = _engine.Devices.FirstOrDefault(d => d.Id == SelectedDeviceId)
                  ?? _engine.Devices.FirstOrDefault();
        if (dev is null) return;
        _engine.PushClipboard(dev, content, ShareEngine.ClipKind(content));
        Draft = "";
    }
}
