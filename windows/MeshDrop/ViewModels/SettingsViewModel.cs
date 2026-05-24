using CommunityToolkit.Mvvm.ComponentModel;

namespace MeshDrop.ViewModels;

public sealed partial class SettingsViewModel : ObservableObject
{
    // 可见性
    [ObservableProperty] private bool _visible = true;
    [ObservableProperty] private string _displayName = "DEV-01 · Win 11";
    [ObservableProperty] private bool _hideAfterIdle = false;

    // 安全/加密
    [ObservableProperty] private bool _e2eRequired = true;
    [ObservableProperty] private bool _autoAccept = false;
    [ObservableProperty] private bool _autoAcceptTrusted = true;
    [ObservableProperty] private bool _requireFingerprintConfirm = true;

    // 行为/接收
    [ObservableProperty] private string _receiveDir = @"C:\Users\dev\Downloads\MeshDrop";
    [ObservableProperty] private bool _ringOnIncoming = true;
    [ObservableProperty] private bool _launchAtLogin = true;
    [ObservableProperty] private bool _showTrayBadge = true;

    public string Fingerprint => "ZX8K · L72M · 9FQ3 · 7HD2";
    public string Ip => "192.168.1.42";
    public string DeviceModel => "Windows 11 Pro · 23H2";
    public string AppVersion => "meshdrop 0.4.0 (build 138)";
}
