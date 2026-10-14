using System;
using System.IO;
using System.Threading.Tasks;
using System.Threading;
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
    private readonly AppSettings _settings = AppSettings.Current;
    private readonly SemaphoreSlim _startupChangeLock = new(1, 1);
    private bool _refreshingStartup;

    // 可见性
    [ObservableProperty] private bool _visible;
    [ObservableProperty] private string _displayName;

    // 安全/加密
    [ObservableProperty] private bool _trustedOnly;

    // 行为/接收
    [ObservableProperty] private string _receiveDir;
    [ObservableProperty] private bool _autoAcceptTrusted;
    [ObservableProperty] private bool _clipboardSync;
    [ObservableProperty] private bool _launchAtLogin;
    [ObservableProperty] private bool _showTrayBadge;

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

        // 从持久化设置 seed 所有开关（缺文件时即默认安全值）。
        _visible = _settings.VisibleOnLan;
        _trustedOnly = _settings.TrustedOnly;
        _autoAcceptTrusted = _settings.AutoAcceptTrusted;
        _clipboardSync = _settings.ClipboardSync;
        // System startup state wins over preferences, including DisabledByUser.
        _launchAtLogin = false;
        _ = RefreshLaunchAtLoginAsync();
        _showTrayBadge = _settings.TrayBadge;

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

    // 以下开关一律「写持久化设置 → Save → 必要时触发引擎运行时副作用」。
    // 引擎在握手/接受判断处实时读 AppSettings.Current，故多数无需额外通知引擎。

    /// <summary>局域网可见：停/启 mDNS 广告（引擎复用现有 listener，仅重起广告面）。</summary>
    partial void OnVisibleChanged(bool value)
    {
        if (_settings.VisibleOnLan == value) return;
        _settings.VisibleOnLan = value;
        _settings.Save();
        _engine.SetAdvertising(value);
    }

    /// <summary>仅显示已配对设备：引擎 HELLO 处理处实时读取，未知 fp 直接关连接。</summary>
    partial void OnTrustedOnlyChanged(bool value)
    {
        if (_settings.TrustedOnly == value) return;
        _settings.TrustedOnly = value;
        _settings.Save();
    }

    /// <summary>自动接收已配对设备：经引擎旧入口同步（其内部已写 settings 并持久化）。</summary>
    partial void OnAutoAcceptTrustedChanged(bool value) => _engine.AutoAcceptFromTrusted = value;

    /// <summary>跨设备剪贴板同步：引擎 PushClipboard / HandleReceivedClipboard 处实时门控。</summary>
    partial void OnClipboardSyncChanged(bool value)
    {
        if (_settings.ClipboardSync == value) return;
        _settings.ClipboardSync = value;
        _settings.Save();
    }

    private async Task RefreshLaunchAtLoginAsync()
    {
        await _startupChangeLock.WaitAsync();
        try
        {
            var enabled = await Models.LaunchAtLogin.IsEnabledAsync();
            _refreshingStartup = true;
            try { LaunchAtLogin = enabled; }
            finally { _refreshingStartup = false; }
            _settings.LaunchAtLogin = enabled;
            _settings.Save();
        }
        finally { _startupChangeLock.Release(); }
    }

    /// <summary>MSIX 使用系统 StartupTask；未打包版本继续使用启动目录快捷方式。</summary>
    partial void OnLaunchAtLoginChanged(bool value)
    {
        if (!_refreshingStartup) _ = ApplyLaunchAtLoginAsync(value);
    }

    private async Task ApplyLaunchAtLoginAsync(bool value)
    {
        await _startupChangeLock.WaitAsync();
        try
        {
            await Models.LaunchAtLogin.SetAsync(value);
            var actual = await Models.LaunchAtLogin.IsEnabledAsync();
            _refreshingStartup = true;
            try { LaunchAtLogin = actual; }
            finally { _refreshingStartup = false; }
            _settings.LaunchAtLogin = actual;
            _settings.Save();
        }
        finally { _startupChangeLock.Release(); }
    }

    /// <summary>托盘活跃数徽标：持久化；tray host 订阅 AppSettings.Changed 刷新显示。</summary>
    partial void OnShowTrayBadgeChanged(bool value)
    {
        if (_settings.TrayBadge == value) return;
        _settings.TrayBadge = value;
        _settings.Save();
    }

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
