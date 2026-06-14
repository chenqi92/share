using System;
using System.IO;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MeshDrop.Gateway;
using MeshDrop.Models;
using MeshDrop.Transport;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MeshDrop.ViewModels;

public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    // 可见性
    [ObservableProperty] private bool _visible = true;
    [ObservableProperty] private string _displayName;
    [ObservableProperty] private bool _hideAfterIdle = false;

    // 安全/加密
    [ObservableProperty] private bool _e2eRequired = true;
    [ObservableProperty] private bool _autoAccept = false;
    [ObservableProperty] private bool _autoAcceptTrusted;
    [ObservableProperty] private bool _requireFingerprintConfirm = true;

    // 行为/接收
    [ObservableProperty] private string _receiveDir;
    [ObservableProperty] private bool _ringOnIncoming = true;
    [ObservableProperty] private bool _launchAtLogin = true;
    [ObservableProperty] private bool _showTrayBadge = true;

    // Web Gateway
    [ObservableProperty] private bool _webGatewayEnabled = true;
    [ObservableProperty] private string _webGatewayUrl = "—";
    [ObservableProperty] private string _webGatewayPairingCode = "—";

    public string Fingerprint => HumanFp(_engine.Identity.Fingerprint);
    public string Ip => _engine.LocalIp;
    public string DeviceModel => _engine.Model ?? "Windows PC";
    public string AppVersion
    {
        get
        {
            var v = typeof(SettingsViewModel).Assembly.GetName().Version;
            return v is null ? "meshdrop" : $"meshdrop {v.Major}.{v.Minor}.{v.Build}";
        }
    }

    public SettingsViewModel()
    {
        _displayName = _engine.DisplayName;
        _autoAcceptTrusted = _engine.AutoAcceptFromTrusted;
        _webGatewayEnabled = GatewayProbe.IsRunning;
        _receiveDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments), "MeshDrop");

        _engine.PropertyChanged += (_, e) =>
        {
            switch (e.PropertyName)
            {
                case nameof(ShareEngine.LocalIp):
                    OnPropertyChanged(nameof(Ip));
                    RefreshGatewayInfo();
                    break;
                case nameof(ShareEngine.DisplayName):
                    if (DisplayName != _engine.DisplayName) DisplayName = _engine.DisplayName;
                    break;
            }
        };

        GatewayProbe.Changed += RefreshGatewayInfo;
        RefreshGatewayInfo();
    }

    private void RefreshGatewayInfo()
    {
        WebGatewayUrl = GatewayProbe.Url ?? "—";
        WebGatewayPairingCode = GatewayProbe.PairingCode ?? "—";
        // 反映外部启停（如别处关掉网关），避免开关显示与实际监听状态不符。
        if (WebGatewayEnabled != GatewayProbe.IsRunning) SetProperty(ref _webGatewayEnabled, GatewayProbe.IsRunning, nameof(WebGatewayEnabled));
    }

    partial void OnDisplayNameChanged(string value) => _engine.SetDisplayName(value);

    partial void OnAutoAcceptTrustedChanged(bool value) => _engine.AutoAcceptFromTrusted = value;

    /// <summary>真正启停对外监听端口（fix #42）：关掉后浏览器无法再连，端口释放。</summary>
    partial void OnWebGatewayEnabledChanged(bool value) => _ = GatewayProbe.SetEnabledAsync(value);

    /// <summary>
    /// 重置身份（security.md §设备身份）。删除 LocalAppData/MeshDrop 下的 ID + 密钥；
    /// 当前 ShareEngine 仍持旧身份运行，需 app 重启才能生效。
    /// </summary>
    [RelayCommand]
    private async Task ResetIdentityAsync(XamlRoot? xamlRoot)
    {
        if (xamlRoot is null) return;
        var confirm = new ContentDialog
        {
            Title = I18n.T("settings.resetDialog.title"),
            Content = I18n.T("settings.resetDialog.body"),
            PrimaryButtonText = I18n.T("settings.resetDialog.confirm"),
            CloseButtonText = I18n.T("common.cancel.Text"),
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = xamlRoot,
        };
        var res = await confirm.ShowAsync();
        if (res != ContentDialogResult.Primary) return;

        Identity.Reset();

        var done = new ContentDialog
        {
            Title = I18n.T("settings.resetDone.title"),
            Content = I18n.T("settings.resetDone.body"),
            CloseButtonText = I18n.T("settings.resetDone.ok"),
            XamlRoot = xamlRoot,
        };
        await done.ShowAsync();
    }

    private static string HumanFp(string fp)
    {
        var up = (fp ?? "").ToUpperInvariant();
        var sb = new System.Text.StringBuilder();
        for (var i = 0; i < up.Length; i += 4)
        {
            if (i > 0) sb.Append(" · ");
            sb.Append(up.Substring(i, Math.Min(4, up.Length - i)));
        }
        return sb.ToString();
    }
}
