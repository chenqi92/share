using System;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using MeshDrop.Gateway;
using MeshDrop.Transport;

namespace MeshDrop;

public partial class App : Application
{
    public static Window? MainWindow { get; private set; }

    private WebGatewayHost? _gateway;

    public App()
    {
        InitializeComponent();
        RequestedTheme = ApplicationTheme.Dark; // Windows 默认进 dark
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        MainWindow = new MainWindow();
        MainWindow.Activate();
        if (MainWindow is Window w) w.Closed += OnMainWindowClosed;

        // 收到文件 offer / 文本 / 剪贴板时弹系统 Toast。
        Notifications.ToastService.Start(ShareEngine.Shared);

        _ = StartBackgroundAsync();
    }

    private async Task StartBackgroundAsync()
    {
        try
        {
            await ShareEngine.Shared.StartAsync();
        }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"engine start fail: {ex}"); }

        try
        {
            _gateway = new WebGatewayHost(ShareEngine.Shared);
            await _gateway.StartAsync();
            GatewayProbe.Publish(_gateway);
        }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"gateway start fail: {ex}"); }
    }

    private void OnMainWindowClosed(object sender, WindowEventArgs args)
    {
        try { _gateway?.Stop(); } catch { }
        try { ShareEngine.Shared.Stop(); } catch { }
        try { Notifications.ToastService.Stop(); } catch { }
    }
}

public static class Program
{
    [System.STAThread]
    public static void Main(string[] args)
    {
        Microsoft.UI.Xaml.Application.Start(param =>
        {
            var ctx = new Microsoft.UI.Dispatching.DispatcherQueueSynchronizationContext(
                Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread());
            System.Threading.SynchronizationContext.SetSynchronizationContext(ctx);
            new App();
        });
    }
}
