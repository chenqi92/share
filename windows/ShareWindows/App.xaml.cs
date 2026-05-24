using Microsoft.UI.Xaml;

namespace MeshDrop;

public partial class App : Application
{
    private Window? _window;

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.Activate();
    }
}

public static class Program
{
    [System.STAThread]
    public static void Main(string[] args)
    {
        Microsoft.UI.Xaml.Application.Start(_ =>
        {
            var ctx = new Microsoft.UI.Dispatching.DispatcherQueueSynchronizationContext(
                Microsoft.UI.Dispatching.DispatcherQueue.GetForCurrentThread());
            System.Threading.SynchronizationContext.SetSynchronizationContext(ctx);
            _ = new App();
        });
    }
}
