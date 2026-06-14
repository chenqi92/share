using System;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MeshDrop.Mock;
using MeshDrop.Transport;
using MeshDrop.ViewModels;
using Windows.ApplicationModel.DataTransfer;

namespace MeshDrop.TrayIcon;

public sealed partial class TrayFlyout : Microsoft.UI.Xaml.Controls.UserControl
{
    public ObservableCollection<MockDevice> Devices { get; }

    public event EventHandler? OpenMainRequested;
    public event EventHandler? OpenSettingsRequested;

    public TrayFlyout()
    {
        Devices = new ProjectedCollection<MeshDrop.Models.Device, MockDevice>(
            ShareEngine.Shared.Devices, d => d.ToMock());
        InitializeComponent();
        // 静态分隔条标签（无计数）走本地化串；NEARBY/ONLINE 带计数的在 UpdateOnlineCount 里设。
        ActionsDivider.Label = I18n.T("tray.actionsDivider");
        Devices.CollectionChanged += OnDevicesChanged;
        UpdateOnlineCount();
    }

    // 每个设备行的「发送」按钮在 DataTemplate 内重复生成、无法 x:Name；
    // 其 ToolTip 是附加属性也不走 x:Uid，统一在 Loaded 时设置本地化串。
    private void SendButton_Loaded(object sender, RoutedEventArgs e)
    {
        if (sender is Button b)
            ToolTipService.SetToolTip(b, I18n.T("tray.sendClipboardTip"));
    }

    private void OpenMain_Click(object sender, RoutedEventArgs e) => OpenMainRequested?.Invoke(this, EventArgs.Empty);
    private void OpenSettings_Click(object sender, RoutedEventArgs e) => OpenSettingsRequested?.Invoke(this, EventArgs.Empty);

    private void OnDevicesChanged(object? sender, NotifyCollectionChangedEventArgs e) => UpdateOnlineCount();

    private void UpdateOnlineCount()
    {
        var n = Devices.Count;
        OnlineCount.Text = I18n.T("tray.onlineCountFormat", n);
        NearbyDivider.Label = I18n.T("tray.nearbyDividerFormat", n);
    }

    /// <summary>
    /// 便捷发送：从剪贴板抓文本 / URI，立即发给该 peer。
    /// 这是 Windows 端"便捷发送"的实装入口 —— 因为 unpackaged WinUI 3 没法注册
    /// Share Target，剪贴板快发是最稳的替代。
    /// </summary>
    private async void SendClipboard_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not Button btn || btn.Tag is not string deviceId) return;

        Models.Device? target = null;
        foreach (var d in ShareEngine.Shared.Devices)
        {
            if (d.Id == deviceId) { target = d; break; }
        }
        if (target is null) return;

        string? text = await ReadClipboardTextAsync();
        if (string.IsNullOrEmpty(text)) return;

        try { ShareEngine.Shared.SendText(target, text); }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"send fail: {ex}"); }
    }

    private static async Task<string?> ReadClipboardTextAsync()
    {
        try
        {
            var view = Clipboard.GetContent();
            if (view.Contains(StandardDataFormats.Text))
                return await view.GetTextAsync();
            if (view.Contains(StandardDataFormats.WebLink))
            {
                var uri = await view.GetWebLinkAsync();
                return uri?.ToString();
            }
            if (view.Contains(StandardDataFormats.Uri))
            {
                var uri = await view.GetUriAsync();
                return uri?.ToString();
            }
        }
        catch { /* clipboard access can race; ignore */ }
        return null;
    }
}
