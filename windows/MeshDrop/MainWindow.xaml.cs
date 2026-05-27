using System;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Windowing;
using MeshDrop.TrayIcon;
using MeshDrop.ViewModels;
using MeshDrop.Views.Shell;
using WinRT.Interop;

namespace MeshDrop;

public sealed partial class MainWindow : Window
{
    private readonly TrayIconHost _tray = new();

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
    }

    private bool _trayReady;

    private void OnActivated(object? sender, WindowActivatedEventArgs args)
    {
        if (_trayReady) return;
        _trayReady = true;
        try
        {
            _tray.Initialize();
        }
        catch
        {
            // Tray init 在 unpackaged 早期失败容忍：UI 仍可用
        }
    }

    private void OnClosed(object sender, WindowEventArgs args)
    {
        _tray.Dispose();
    }

    private void OnSectionChanged(object? sender, ShellSection section) => ShowSection(section);

    private void OnPeerChosen(object? sender, string peerId) => ShowSection(ShellSection.Chat);

    private void ShowSection(ShellSection section)
    {
        DiscoveryPg.Visibility = Visibility.Collapsed;
        ChatPg.Visibility = Visibility.Collapsed;
        TransfersPg.Visibility = Visibility.Collapsed;
        HistoryPg.Visibility = Visibility.Collapsed;
        TrustPg.Visibility = Visibility.Collapsed;
        SettingsPg.Visibility = Visibility.Collapsed;

        switch (section)
        {
            case ShellSection.Discovery: DiscoveryPg.Visibility = Visibility.Visible; break;
            case ShellSection.Chat:      ChatPg.Visibility = Visibility.Visible;      break;
            case ShellSection.Transfers: TransfersPg.Visibility = Visibility.Visible; break;
            case ShellSection.History:   HistoryPg.Visibility = Visibility.Visible;   break;
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
            aw?.Resize(new Windows.Graphics.SizeInt32(1280, 820));
        }
        catch { }
    }
}
