using System;
using System.Linq;
using System.Collections.Generic;
using MeshDrop.Models;
using Windows.ApplicationModel.DataTransfer;
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
    private readonly HashSet<string> _pairFailed = new();
    private readonly HashSet<string> _pairing = new();

    private Device? SelectedDevice => ShareEngine.Shared.Devices.FirstOrDefault(d =>
        d.Id == ViewModel.SelectedId && d.HumanFingerprint == ViewModel.Selected?.Fingerprint);

    /// <summary>选中对端后请求打开会话（MainWindow 据此切到 Chat 并定位对端）。</summary>
    public event EventHandler<string>? StartSessionRequested;

    public DiscoveryPage()
    {
        ViewModel = new DiscoveryViewModel();
        InitializeComponent();
        RadarCtl.DeviceSelected += (_, id) => ViewModel.SelectedId = id;
        // 自定义 ChipControl 的 Text DP 不走 x:Uid，在此设置本地化串。
        LiveChip.Text = I18n.T("discovery.chipLive");
        PlaintextChip.Text = I18n.T("discovery.chipPlaintext");
        LanOnlyChip.Text = I18n.T("discovery.chipLanOnly");
        Loaded += (_, _) =>
        {
            ViewModel.PropertyChanged += OnVmChanged;
            ShareEngine.Shared.Devices.CollectionChanged += OnDevicesChanged;
            ShareEngine.Shared.Trusted.CollectionChanged += OnTrustChanged;
            Refresh();
        };
        Unloaded += (_, _) =>
        {
            ViewModel.PropertyChanged -= OnVmChanged;
            ShareEngine.Shared.Devices.CollectionChanged -= OnDevicesChanged;
            ShareEngine.Shared.Trusted.CollectionChanged -= OnTrustChanged;
        };
    }

    private void OnVmChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(Refresh);
    }

    private void OnTrustChanged(object? sender, System.Collections.Specialized.NotifyCollectionChangedEventArgs e) => Refresh();

    private void OnDevicesChanged(object? sender, System.Collections.Specialized.NotifyCollectionChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(() => { RadarCtl.Rebuild(); Refresh(); });
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

        var fp = SelectedDevice?.Fingerprint;
        bool trusted = fp is not null && ShareEngine.Shared.Trusted.Any(t => t.Fingerprint == fp);
        PairButton.Visibility = trusted ? Visibility.Collapsed : Visibility.Visible;
        PairButton.IsEnabled = fp is not null && !_pairing.Contains(fp);
        string? status = null;
        if (fp is not null)
        {
            if (_pairing.Contains(fp)) status = "discovery.pairWaiting";
            else if (trusted) status = "discovery.pairSaved";
            else if (_pairFailed.Contains(fp)) status = "discovery.pairFailed";
        }
        PairStatus.Text = status is null ? "" : I18n.T(status);
        PairStatus.Visibility = PairStatus.Text.Length > 0 ? Visibility.Visible : Visibility.Collapsed;
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

    private async void OnSelectedClipboard(object sender, RoutedEventArgs e)
    {
        if (SelectedDevice is not { } peer) return;
        try
        {
            var view = Clipboard.GetContent();
            if (!view.Contains(StandardDataFormats.Text)) return;
            var content = await view.GetTextAsync();
            ShareEngine.Shared.PushClipboard(peer, content, ShareEngine.ClipKind(content));
        }
        catch (System.Runtime.InteropServices.COMException) { /* Clipboard became unavailable. */ }
    }

    private async void OnSelectedPair(object sender, RoutedEventArgs e)
    {
        if (SelectedDevice is not { } peer || !_pairing.Add(peer.Fingerprint)) return;
        _pairFailed.Remove(peer.Fingerprint);
        Refresh();
        try
        {
            bool paired = await ShareEngine.Shared.RequestPairingAsync(peer);
            if (!paired) _pairFailed.Add(peer.Fingerprint);
        }
        finally
        {
            _pairing.Remove(peer.Fingerprint);
            Refresh();
        }
    }

    private void OnSelectedChat(object sender, RoutedEventArgs e)
    {
        if (SelectedDevice is { } peer) StartSessionRequested?.Invoke(this, peer.Id);
    }

    private async void OnSelectedSend(object sender, RoutedEventArgs e)
    {
        if (SelectedDevice is { } peer) await PickAndSendAsync(peer);
    }

    private void OnDeviceDragOver(object sender, DragEventArgs e)
    {
        e.AcceptedOperation = SelectedDevice is not null && e.DataView.Contains(StandardDataFormats.StorageItems)
            ? DataPackageOperation.Copy : DataPackageOperation.None;
    }

    private async void OnDeviceDrop(object sender, DragEventArgs e)
    {
        if (SelectedDevice is not { } peer || !e.DataView.Contains(StandardDataFormats.StorageItems)) return;
        var sent = false;
        try
        {
            foreach (var file in (await e.DataView.GetStorageItemsAsync()).OfType<StorageFile>())
            {
                if (string.IsNullOrEmpty(file.Path)) continue;
                ShareEngine.Shared.SendFile(peer, file.Path);
                sent = true;
            }
        }
        catch (Exception error) when (error is System.IO.IOException or UnauthorizedAccessException
            or System.Runtime.InteropServices.COMException)
        {
            ErrorText.Text = error.Message;
            ErrorBanner.Visibility = Visibility.Visible;
        }
        if (sent) StartSessionRequested?.Invoke(this, peer.Id);
    }

    // 「发送文件…」：先选文件，再选目标设备，发出后打开与该对端的会话便于查看进度。
    private async void OnSendFile_Click(object sender, RoutedEventArgs e) => await PickAndSendAsync(null);

    private async Task PickAndSendAsync(Device? peer)
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

        if (peer is null)
        {
            var peerId = await PickPeerAsync(I18n.T("send.send"));
            peer = ShareEngine.Shared.Devices.FirstOrDefault(d => d.Id == peerId);
        }
        if (peer is null) return;

        ShareEngine.Shared.SendFile(peer, file.Path);
        StartSessionRequested?.Invoke(this, peer.Id);
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
