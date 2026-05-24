using System;
using System.IO;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Gateway;
using MeshDrop.Transport;

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
