using System;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.Linq;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MeshDrop.Mock;
using MeshDrop.Models;
using MeshDrop.Transport;
using Windows.Storage;
using Windows.Storage.Pickers;

namespace MeshDrop.ViewModels;

public sealed partial class ChatViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    [ObservableProperty]
    private string _peerId = "";

    [ObservableProperty]
    private string _peerDisplayName = "—";

    [ObservableProperty]
    private string _peerSubtitle = I18n.T("chat.noPeer");

    /// <summary>composer 输入草稿。SendText 后清空。</summary>
    [ObservableProperty]
    private string _draft = "";

    [ObservableProperty]
    private string _peerInitials = "—";

    [ObservableProperty]
    private string _peerColorHex = "#9AD0FF";

    private readonly ProjectedCollection<HistoryItem, MockMessage> _messages;
    public ObservableCollection<MockDevice> Devices { get; }
    public ObservableCollection<MockMessage> Messages => _messages;

    /// <summary>取当前选中对端（按 PeerId 在设备表里查）。无选中返回 null。</summary>
    private Device? CurrentPeer =>
        string.IsNullOrEmpty(PeerId) ? null : _engine.Devices.FirstOrDefault(d => d.Id == PeerId);

    public string DropOverlayText
    {
        get
        {
            var name = string.IsNullOrEmpty(PeerDisplayName) ? I18n.T("chat.peerFallback") : PeerDisplayName;
            return I18n.T("chat.dropOverlayFormat", name);
        }
    }

    public ChatViewModel()
    {
        Devices = new ProjectedCollection<MeshDrop.Models.Device, MockDevice>(
            _engine.Devices, d => d.ToMock());
        Devices.CollectionChanged += OnDevicesChanged;

        _messages = new ProjectedCollection<HistoryItem, MockMessage>(
            _engine.History,
            h => h.ToMessage(),
            h => string.IsNullOrEmpty(PeerId) || h.Peer.Id == PeerId);

        if (string.IsNullOrEmpty(PeerId) && Devices.Count > 0)
        {
            PeerId = Devices[0].Id;
        }
    }

    public bool SendText(string content)
    {
        var text = (content ?? "").Trim();
        if (string.IsNullOrEmpty(text) || string.IsNullOrEmpty(PeerId)) return false;

        var peer = _engine.Devices.FirstOrDefault(d => d.Id == PeerId);
        if (peer is null) return false;

        _engine.SendText(peer, text);
        return true;
    }

    partial void OnPeerIdChanged(string value)
    {
        _messages.Refresh();
        var peer = _engine.Devices.FirstOrDefault(d => d.Id == value);
        if (peer is not null)
        {
            PeerDisplayName = peer.Name;
            PeerSubtitle = $"{peer.Os} · {peer.Host ?? "—"}";
            PeerInitials = EngineProjection.Initials(peer.Name);
            PeerColorHex = EngineProjection.ColorFromId(peer.Id);
        }
        else
        {
            PeerDisplayName = "—";
            PeerSubtitle = "未选择对端";
            PeerInitials = "—";
            PeerColorHex = "#9AD0FF";
        }
        OnPropertyChanged(nameof(DropOverlayText));
    }

    /// <summary>发送草稿文本给当前对端。空草稿 / 无对端时静默忽略。</summary>
    [RelayCommand]
    private void SendText()
    {
        var content = (Draft ?? "").Trim();
        if (content.Length == 0) return;
        if (CurrentPeer is not { } peer) return;
        _engine.SendText(peer, content);
        Draft = "";
    }

    /// <summary>
    /// 「+ 文件」：弹 FileOpenPicker 选文件发给当前对端。WinUI 3 的 Picker 需
    /// InitializeWithWindow 绑定窗口句柄，否则在 unpackaged 下抛 COM 异常。
    /// </summary>
    [RelayCommand]
    private async Task PickAndSendFileAsync()
    {
        if (CurrentPeer is not { } peer) return;
        if (App.MainWindow is not { } window) return;

        var picker = new FileOpenPicker { SuggestedStartLocation = PickerLocationId.DocumentsLibrary };
        picker.FileTypeFilter.Add("*");

        // WinUI 3 Picker 在 unpackaged 下必须绑定窗口句柄，否则 PickSingleFileAsync 抛 COM。
        var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(window);
        WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

        StorageFile? file;
        try { file = await picker.PickSingleFileAsync(); }
        catch { return; }
        if (file is null) return;
        _engine.SendFile(peer, file.Path);
    }

    /// <summary>拖拽落下的文件路径直接发给当前对端（ChatPage Drop 调）。</summary>
    public void SendDroppedFile(string path)
    {
        if (CurrentPeer is not { } peer) return;
        if (string.IsNullOrEmpty(path) || !System.IO.File.Exists(path)) return;
        _engine.SendFile(peer, path);
    }

    private void OnDevicesChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (string.IsNullOrEmpty(PeerId) && Devices.Count > 0)
        {
            PeerId = Devices[0].Id;
        }
    }
}
