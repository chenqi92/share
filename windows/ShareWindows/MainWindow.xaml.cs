using MeshDrop.ViewModels;
using Microsoft.UI.Xaml;
using WinRT.Interop;

namespace MeshDrop;

public sealed partial class MainWindow : Window
{
    public DeviceListViewModel ViewModel { get; }

    public MainWindow()
    {
        ViewModel = new DeviceListViewModel();
        InitializeComponent();
        Title = "MeshDrop";
        SetWindowIcon();
        Closed += (_, _) => ViewModel.Stop();
        _ = ViewModel.StartAsync();
    }

    private void SetWindowIcon()
    {
        // 任务栏 / 标题栏图标。Assets\AppIcon.ico 由 iconforge 生成、csproj
        // 标记为 Content，运行期与 exe 同目录。
        try
        {
            var hwnd = WindowNative.GetWindowHandle(this);
            var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hwnd);
            var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(windowId);
            appWindow?.SetIcon(@"Assets\AppIcon.ico");
        }
        catch
        {
            // 图标缺失或 API 不可用时静默跳过——只影响外观，不影响功能
        }
    }
}
