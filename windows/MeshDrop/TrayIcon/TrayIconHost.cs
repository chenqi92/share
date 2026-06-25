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
    private TrayFlyout? _flyoutContent;
    private Flyout? _flyout;

    private ShareEngine? _engine;
    private DispatcherQueue? _ui;

    public event EventHandler? OpenMainRequested;
    public event EventHandler? OpenSettingsRequested;

    public void Initialize()
    {
        _ui = DispatcherQueue.GetForCurrentThread();
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
            ToolTipText = MeshDrop.I18n.T("tray.tooltipFormat", 0),
            ContextFlyout = _flyout,
            // 右键托盘要弹自定义 WinUI Flyout：默认 PopupMenu 模式会把 ContextFlyout 强转 MenuFlyout，
            // 我们给的是 Flyout(含富内容 TrayFlyout) → InvalidCastException 崩溃。改 SecondWindow 模式正常显示。
            ContextMenuMode = H.NotifyIcon.ContextMenuMode.SecondWindow,
            // H.NotifyIcon 2.x 把 ImageSource 转成 System.Drawing.Icon（new Icon(stream) 需要 ICO 而非 PNG）；
            // 喂 PNG 会在 OnIconSourceChanged 的 async-void 里抛 ArgumentException 崩掉整个应用。
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
