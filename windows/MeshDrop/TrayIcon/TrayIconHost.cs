using System;
using System.Linq;
using H.NotifyIcon;
using MeshDrop.Models;
using MeshDrop.Transport;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;
using Microsoft.UI.Xaml.Media.Imaging;

namespace MeshDrop.TrayIcon;

/// <summary>
/// 使用 H.NotifyIcon.WinUI 提供系统托盘图标 + Flyout（不再用 deprecated System.Drawing.NotifyIcon）。
/// 生命周期由 MainWindow 持有。
/// </summary>
public sealed class TrayIconHost : IDisposable
{
    private TaskbarIcon? _icon;

    private ShareEngine? _engine;
    private DispatcherQueue? _ui;

    public event EventHandler? OpenMainRequested;
    public event EventHandler? OpenSettingsRequested;

    public void Initialize()
    {
        _ui = DispatcherQueue.GetForCurrentThread();
        // 右键菜单用原生 MenuFlyout：H.NotifyIcon 默认 PopupMenu 模式要求 MenuFlyout（走 Win32 菜单）。
        // 之前用富内容 Flyout 会被强转 MenuFlyout 崩溃（右键闪退）；改 SecondWindow 模式又会在托盘初始化时
        // 创建第二窗口、在 unpackaged 下创建富控件失败导致启动即闪退。MenuFlyout 最稳，三处崩溃一并避开。
        var menu = new MenuFlyout();
        var openItem = new MenuFlyoutItem { Text = MeshDrop.I18n.T("tray.menuOpen") };
        openItem.Click += (_, _) => OpenMainRequested?.Invoke(this, EventArgs.Empty);
        var settingsItem = new MenuFlyoutItem { Text = MeshDrop.I18n.T("tray.menuSettings") };
        settingsItem.Click += (_, _) => OpenSettingsRequested?.Invoke(this, EventArgs.Empty);
        var exitItem = new MenuFlyoutItem { Text = MeshDrop.I18n.T("tray.menuExit") };
        exitItem.Click += (_, _) => Microsoft.UI.Xaml.Application.Current.Exit();
        menu.Items.Add(openItem);
        menu.Items.Add(settingsItem);
        menu.Items.Add(new MenuFlyoutSeparator());
        menu.Items.Add(exitItem);

        _icon = new TaskbarIcon
        {
            ToolTipText = MeshDrop.I18n.T("tray.tooltipFormat", 0),
            ContextFlyout = menu,
            // H.NotifyIcon 2.x 用 System.Drawing.Icon(stream) 需要 ICO；喂 PNG 会在 async-void 里抛异常崩溃。
            // unpackaged 下 ms-appx 不可靠，用输出目录里的本地 .ico 文件绝对路径。
            IconSource = new BitmapImage(new Uri(System.IO.Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico"))),
            NoLeftClickDelay = true,
            LeftClickCommand = new RelayCommand(_ => OpenMainRequested?.Invoke(this, EventArgs.Empty)),
        };
        _icon.ForceCreate();
        RefreshTooltip();
    }

    /// <summary>
    /// 绑定引擎：托盘 tooltip 随「活跃传输数」更新（受 settings.trayBadge 门控）。
    /// 徽标关闭时只显示「附近 N 台」，开启时显示「活跃 N」。订阅 History 变化 +
    /// AppSettings.Changed，回 UI 线程刷新（H.NotifyIcon 属性须 UI 线程改）。
    /// </summary>
    public void Attach(ShareEngine engine)
    {
        _engine = engine;
        engine.History.CollectionChanged += (_, _) => RefreshTooltip();
        engine.Devices.CollectionChanged += (_, _) => RefreshTooltip();
        AppSettings.Changed += RefreshTooltip;
        RefreshTooltip();
    }

    private void RefreshTooltip()
    {
        if (_icon is null) return;
        void Apply()
        {
            if (_icon is null) return;
            string tip;
            if (AppSettings.Current.TrayBadge && _engine is not null)
            {
                var active = _engine.History.Count(h =>
                    h.Status is Models.TransferStatus.Transferring
                        or Models.TransferStatus.Pending
                        or Models.TransferStatus.WaitingApproval);
                tip = MeshDrop.I18n.T("tray.activeFormat", active);
            }
            else
            {
                tip = MeshDrop.I18n.T("tray.tooltipFormat", _engine?.Devices.Count ?? 0);
            }
            try { _icon.ToolTipText = tip; } catch { }
        }
        // 可能从引擎后台线程触发，切回 UI 线程。
        if (_ui is { } ui && !ui.HasThreadAccess) ui.TryEnqueue(Apply);
        else Apply();
    }

    /// <summary>对外暴露：从全局热键 WIN+S 触发展开。</summary>
    public void ShowFlyout()
    {
        // H.NotifyIcon 2.x: ShowContextMenu(System.Drawing.Point cursorPosition)
        _icon?.ShowContextMenu(default(System.Drawing.Point));
    }

    public void Dispose()
    {
        AppSettings.Changed -= RefreshTooltip;
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
