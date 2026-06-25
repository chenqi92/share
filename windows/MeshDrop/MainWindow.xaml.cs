using System;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using MeshDrop.Models;
using MeshDrop.Transport;
using MeshDrop.TrayIcon;
using MeshDrop.ViewModels;
using MeshDrop.Views.Dialogs;
using MeshDrop.Views.Shell;
using WinRT.Interop;

namespace MeshDrop;

public sealed partial class MainWindow : Window
{
    private readonly TrayIconHost _tray = new();
    private bool _isActive;
    private bool _pairingDialogOpen;

    public MainWindow()
    {
        InitializeComponent();
        Title = "meshdrop · MeshDrop";
        SetWindowIcon();
        SetInitialSize();
        Sidebar.SectionChanged += OnSectionChanged;
        Sidebar.PeerChosen += OnPeerChosen;
        _tray.OpenMainRequested += (_, _) => Activate();
        _tray.OpenSettingsRequested += (_, _) =>
        {
            Activate();
            ShowSection(ShellSection.Settings);
        };
        Activated += OnActivated;
        Closed += OnClosed;

        // 窗口在前台时，TOFU 待审配对直接弹审批对话框（后台时由 Toast 承接）。
        ShareEngine.Shared.Event += OnEngineEvent;
    }

    private bool _trayReady;

    private void OnActivated(object? sender, WindowActivatedEventArgs args)
    {
        _isActive = args.WindowActivationState != WindowActivationState.Deactivated;

        if (_trayReady) return;
        _trayReady = true;
        try
        {
            _tray.Initialize();
            // 托盘 tooltip 随活跃传输数刷新（受 settings.trayBadge 门控）。
            _tray.Attach(ShareEngine.Shared);
        }
        catch
        {
            // Tray init 在 unpackaged 早期失败容忍：UI 仍可用
        }
    }

    private void OnClosed(object sender, WindowEventArgs args)
    {
        ShareEngine.Shared.Event -= OnEngineEvent;
        _tray.Dispose();
    }

    private void OnEngineEvent(EngineEvent ev)
    {
        if (ev is not EngineEvent.PairingPending p) return;
        // Event 可能来自后台连接线程，切回 UI 线程再弹 ContentDialog。
        DispatcherQueue.TryEnqueue(() => _ = TryShowPairingDialogAsync(p.Pairing));
    }

    private async System.Threading.Tasks.Task TryShowPairingDialogAsync(PendingPairing pairing)
    {
        // 仅在窗口前台且当前没有其它配对对话框时弹（避免与 Toast 重复打扰 / 多弹叠加）。
        if (!_isActive || _pairingDialogOpen) return;
        if (Content is not FrameworkElement root || root.XamlRoot is null) return;

        _pairingDialogOpen = true;
        try
        {
            var dialog = new PairingDialog(PendingPairingVM.From(pairing)) { XamlRoot = root.XamlRoot };
            await dialog.ShowAsync();
            // 用户已选 → 回传引擎；外部关闭（Decision==null）则不动，留给 Trust 页 / Toast。
            if (dialog.Decision is { } decision)
                ShareEngine.Shared.RespondToPairing(pairing.Id, decision);
        }
        catch { /* XamlRoot 失效 / 已有对话框时容忍 */ }
        finally { _pairingDialogOpen = false; }
    }

    private void OnSectionChanged(object? sender, ShellSection section) => ShowSection(section);

    private void OnPeerChosen(object? sender, string peerId) => ShowSection(ShellSection.Chat);

    private void ShowSection(ShellSection section)
    {
        DiscoveryPg.Visibility = Visibility.Collapsed;
        ChatPg.Visibility = Visibility.Collapsed;
        TransfersPg.Visibility = Visibility.Collapsed;
        HistoryPg.Visibility = Visibility.Collapsed;
        ClipboardPg.Visibility = Visibility.Collapsed;
        TrustPg.Visibility = Visibility.Collapsed;
        SettingsPg.Visibility = Visibility.Collapsed;

        switch (section)
        {
            case ShellSection.Discovery: DiscoveryPg.Visibility = Visibility.Visible; break;
            case ShellSection.Chat:      ChatPg.Visibility = Visibility.Visible;      break;
            case ShellSection.Transfers: TransfersPg.Visibility = Visibility.Visible; break;
            case ShellSection.History:   HistoryPg.Visibility = Visibility.Visible;   break;
            case ShellSection.Clipboard: ClipboardPg.Visibility = Visibility.Visible; break;
            case ShellSection.Trust:     TrustPg.Visibility = Visibility.Visible;     break;
            case ShellSection.Settings:  SettingsPg.Visibility = Visibility.Visible;  break;
        }
    }

    private void SetWindowIcon()
    {
        try
        {
            var hwnd = WindowNative.GetWindowHandle(this);
            var id = Win32Interop.GetWindowIdFromWindow(hwnd);
            var aw = AppWindow.GetFromWindowId(id);
            aw?.SetIcon(@"Assets\AppIcon.ico");
            if (aw?.TitleBar is { } tb)
            {
                tb.ExtendsContentIntoTitleBar = false;
            }
        }
        catch { }
    }

    private void SetInitialSize()
    {
        try
        {
            var hwnd = WindowNative.GetWindowHandle(this);
            var id = Win32Interop.GetWindowIdFromWindow(hwnd);
            var aw = AppWindow.GetFromWindowId(id);
            if (aw is null) return;
            // 默认按显示器工作区的 82% × 86% 取尺寸并居中（跨分辨率/DPI 自适应，避免默认窗口过小）。
            var da = DisplayArea.GetFromWindowId(id, DisplayAreaFallback.Primary);
            if (da is not null)
            {
                var wa = da.WorkArea;
                int w = (int)(wa.Width * 0.82);
                int h = (int)(wa.Height * 0.86);
                aw.MoveAndResize(new Windows.Graphics.RectInt32(
                    wa.X + (wa.Width - w) / 2, wa.Y + (wa.Height - h) / 2, w, h));
            }
            else
            {
                aw.Resize(new Windows.Graphics.SizeInt32(1600, 1000));
            }
        }
        catch { }
    }
}
