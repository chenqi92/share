using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MeshDrop.Transport;
using MeshDrop.ViewModels;
using MeshDrop.Views.Dialogs;
using Windows.Storage;
using Windows.Storage.Pickers;

namespace MeshDrop.Views.Pages;

public sealed partial class DiscoveryPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public DiscoveryViewModel ViewModel { get; }

    /// <summary>选中对端后请求打开会话（MainWindow 据此切到 Chat 并定位对端）。</summary>
    public event EventHandler<string>? StartSessionRequested;

    public DiscoveryPage()
    {
        ViewModel = new DiscoveryViewModel();
        InitializeComponent();
        // 自定义 ChipControl 的 Text DP 不走 x:Uid，在此设置本地化串。
        LiveChip.Text = I18n.T("discovery.chipLive");
        PlaintextChip.Text = I18n.T("discovery.chipPlaintext");
        LanOnlyChip.Text = I18n.T("discovery.chipLanOnly");
        Loaded += (_, _) => { Refresh(); ViewModel.PropertyChanged += OnVmChanged; ViewModel.Devices.CollectionChanged += OnDevicesChanged; };
        Unloaded += (_, _) => { ViewModel.PropertyChanged -= OnVmChanged; ViewModel.Devices.CollectionChanged -= OnDevicesChanged; };
    }

    private void OnVmChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(Refresh);
    }

    private void OnDevicesChanged(object? sender, System.Collections.Specialized.NotifyCollectionChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(Refresh);
    }

    private void Refresh()
    {
        ScanningBanner.Visibility = ViewModel.IsScanning && ViewModel.Devices.Count == 0
            ? Visibility.Visible : Visibility.Collapsed;

        if (ViewModel.LastError is { } err && !string.IsNullOrEmpty(err))
        {
            ErrorText.Text = I18n.T("discovery.networkErrorFormat", err);
            ErrorBanner.Visibility = Visibility.Visible;
        }
        else
        {
            ErrorBanner.Visibility = Visibility.Collapsed;
        }

        EmptyCard.Visibility = ViewModel.IsEmpty ? Visibility.Visible : Visibility.Collapsed;
        // 雷达页脚分隔条：含可读词（扫描/脉冲/台数），整体走本地化模板，{0} 为设备数。
        FooterDivider.Label = I18n.T("discovery.sweepFooterFormat", ViewModel.Devices.Count);
    }

    // 「+ 新会话」：弹设备选择框，选中后请求打开与该对端的会话。
    private async void OnNewSession_Click(object sender, RoutedEventArgs e)
    {
        var peerId = await PickPeerAsync(null);
        if (!string.IsNullOrEmpty(peerId))
            StartSessionRequested?.Invoke(this, peerId);
    }

    // 「发送文件…」：先选文件，再选目标设备，发出后打开与该对端的会话便于查看进度。
    private async void OnSendFile_Click(object sender, RoutedEventArgs e)
    {
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

        var peerId = await PickPeerAsync(I18n.T("send.send"));
        if (string.IsNullOrEmpty(peerId)) return;

        var peer = ShareEngine.Shared.Devices.FirstOrDefault(d => d.Id == peerId);
        if (peer is null) return;

        ShareEngine.Shared.SendFile(peer, file.Path);
        StartSessionRequested?.Invoke(this, peerId);
    }

    // 弹设备选择对话框，返回选中对端 Id；取消或未选返回空串。
    private async Task<string> PickPeerAsync(string? primaryText)
    {
        if (XamlRoot is null) return "";
        var dialog = new NewSessionDialog(primaryText) { XamlRoot = XamlRoot };
        var res = await dialog.ShowAsync();
        return res == ContentDialogResult.Primary ? dialog.SelectedPeerId : "";
    }
}
