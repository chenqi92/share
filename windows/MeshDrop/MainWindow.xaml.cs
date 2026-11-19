using System;
using System.Collections.Specialized;
using System.IO;
using System.Linq;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using MeshDrop.Models;
using MeshDrop.Transport;
using MeshDrop.TrayIcon;
using MeshDrop.ViewModels;
using MeshDrop.Views.Shell;
using WinRT.Interop;

namespace MeshDrop;

public sealed partial class MainWindow : Window
{
    private readonly TrayIconHost _tray = new();
    internal bool IsWindowActive { get; private set; }

    public MainWindow()
    {
        InitializeComponent();
        Title = "meshdrop · MeshDrop";
        SetWindowIcon();
        SetInitialSize();
        Sidebar.SectionChanged += OnSectionChanged;
        Sidebar.PeerChosen += OnPeerChosen;
        DiscoveryPg.StartSessionRequested += OnPeerChosen;
        _tray.OpenMainRequested += (_, _) => Activate();
        _tray.OpenSettingsRequested += (_, _) =>
        {
            Activate();
            ShowSection(ShellSection.Settings);
        };
        Activated += OnActivated;
        Closed += OnClosed;

        ShareEngine.Shared.PendingPairings.CollectionChanged += OnPendingChanged;
        ShareEngine.Shared.PendingFileOffers.CollectionChanged += OnPendingChanged;
        AllowOnceButton.Content = I18n.T("toast.allowOnce");
        RejectButton.Content = I18n.T("toast.reject");
        RefreshIncoming();
    }

    private bool _trayReady;

    private void OnActivated(object? sender, WindowActivatedEventArgs args)
    {
        IsWindowActive = args.WindowActivationState != WindowActivationState.Deactivated;

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
        ShareEngine.Shared.PendingPairings.CollectionChanged -= OnPendingChanged;
        ShareEngine.Shared.PendingFileOffers.CollectionChanged -= OnPendingChanged;
        _tray.Dispose();
    }

    private void OnPendingChanged(object? sender, NotifyCollectionChangedEventArgs e) => RefreshIncoming();

    private void RefreshIncoming()
    {
        var engine = ShareEngine.Shared;
        var pairing = engine.PendingPairings.FirstOrDefault();
        var offer = engine.PendingFileOffers.FirstOrDefault();
        IncomingBar.Tag = (object?)pairing ?? offer;
        IncomingBar.IsOpen = IncomingBar.Tag is not null;
        AllowOnceButton.Visibility = pairing is null ? Visibility.Collapsed : Visibility.Visible;
        if (pairing is not null)
        {
            IncomingBar.Title = I18n.T("toast.pairingTitleFormat", pairing.Peer.Name);
            IncomingBar.Message = I18n.T("toast.fingerprintFormat", pairing.Peer.HumanFingerprint);
            AcceptButton.Content = I18n.T("toast.allowRemember");
        }
        else if (offer is not null)
        {
            IncomingBar.Title = I18n.T("toast.incomingFileTitleFormat", offer.Peer.Name);
            IncomingBar.Message = $"{offer.FileName} · {offer.FormattedSize}";
            AcceptButton.Content = I18n.T("toast.accept");
        }
    }

    private void OnIncomingDecision(object sender, RoutedEventArgs e)
    {
        if (IncomingBar.Tag is PendingPairing pairing)
        {
            var decision = sender == AcceptButton ? PairingDecision.Trust
                : sender == AllowOnceButton ? PairingDecision.AllowOnce : PairingDecision.Reject;
            ShareEngine.Shared.RespondToPairing(pairing.Id, decision);
        }
        else if (IncomingBar.Tag is PendingFileOffer offer)
            ShareEngine.Shared.RespondToFileOffer(offer.Id, sender == AcceptButton);
    }

    private void OnSectionChanged(object? sender, ShellSection section) => ShowSection(section);

    private void OnPeerChosen(object? sender, string peerId)
    {
        // 把选中的对端喂给 ChatViewModel，否则 Chat 页只会显示设备表里的第一台。
        if (!string.IsNullOrEmpty(peerId))
            ChatPg.ViewModel.PeerId = peerId;
        Sidebar.SetActiveSection(ShellSection.Chat);
        ShowSection(ShellSection.Chat);
    }

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
            aw?.SetIcon(Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico"));
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
