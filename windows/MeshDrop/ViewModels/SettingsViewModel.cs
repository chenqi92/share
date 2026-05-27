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
    [ObservableProperty] private bool _autoAcceptTrusted = true;
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
    public string AppVersion => "meshdrop 0.4.0 (build 200)";

    public SettingsViewModel()
    {
        _displayName = _engine.DisplayName;
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
    }

    partial void OnDisplayNameChanged(string value) => _engine.SetDisplayName(value);

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
            Title = "重置身份",
            Content = "将删除当前 ID 与 Ed25519 私钥，所有已配对的对端会把本机视为新设备需要重新配对。重置后需重启 MeshDrop 让新身份生效。",
            PrimaryButtonText = "重置",
            CloseButtonText = "取消",
            DefaultButton = ContentDialogButton.Close,
            XamlRoot = xamlRoot,
        };
        var res = await confirm.ShowAsync();
        if (res != ContentDialogResult.Primary) return;

        Identity.Reset();

        var done = new ContentDialog
        {
            Title = "已重置",
            Content = "身份已删除。请退出并重启 MeshDrop 让新身份生效。",
            CloseButtonText = "好",
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
