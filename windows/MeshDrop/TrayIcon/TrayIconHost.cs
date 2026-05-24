using System;
using H.NotifyIcon;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;

namespace MeshDrop.TrayIcon;

/// <summary>
/// 使用 H.NotifyIcon.WinUI 提供系统托盘图标 + Flyout（不再用 deprecated System.Drawing.NotifyIcon）。
/// 生命周期由 MainWindow 持有。
/// </summary>
public sealed class TrayIconHost : IDisposable
{
    private TaskbarIcon? _icon;
    private TrayFlyout? _flyoutContent;
    private Flyout? _flyout;

    public event EventHandler? OpenMainRequested;
    public event EventHandler? OpenSettingsRequested;

    public void Initialize()
    {
        _flyoutContent = new TrayFlyout();
        _flyoutContent.OpenMainRequested += (s, e) => OpenMainRequested?.Invoke(s, e);
        _flyoutContent.OpenSettingsRequested += (s, e) => OpenSettingsRequested?.Invoke(s, e);

        _flyout = new Flyout
        {
            Content = _flyoutContent,
            Placement = FlyoutPlacementMode.TopEdgeAlignedRight,
            ShouldConstrainToRootBounds = false,
        };

        _icon = new TaskbarIcon
        {
            ToolTipText = "meshdrop · 附近 5 台",
            ContextFlyout = _flyout,
            IconSource = new BitmapIconSource
            {
                UriSource = new Uri("ms-appx:///Assets/AppIcon.png"),
                ShowAsMonochrome = false,
            },
            NoLeftClickDelay = true,
            LeftClickCommand = new RelayCommand(_ => OpenMainRequested?.Invoke(this, EventArgs.Empty)),
        };
        _icon.ForceCreate();
    }

    /// <summary>对外暴露：从全局热键 WIN+S 触发展开。</summary>
    public void ShowFlyout()
    {
        _icon?.ShowContextMenu();
    }

    public void Dispose()
    {
        _icon?.Dispose();
        _icon = null;
    }
}

internal sealed class RelayCommand : System.Windows.Input.ICommand
{
    private readonly Action<object?> _action;

    public RelayCommand(Action<object?> action)
    {
        _action = action;
    }

    public event EventHandler? CanExecuteChanged;
    public bool CanExecute(object? parameter) => true;
    public void Execute(object? parameter) => _action(parameter);
}
