using System.Collections.Specialized;
using System.Linq;
using MeshDrop.Models;
using MeshDrop.ViewModels;
using MeshDrop.Views;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
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

        // 监听 pending pairing / file offer，自动弹 dialog
        ViewModel.Engine.PendingPairings.CollectionChanged += OnPendingPairingsChanged;
        ViewModel.Engine.PendingFileOffers.CollectionChanged += OnPendingOffersChanged;
    }

    // 设备卡片点击 → 弹 SendDialog
    private async void DeviceCard_Tapped(object sender, Microsoft.UI.Xaml.Input.TappedRoutedEventArgs e)
    {
        if (sender is FrameworkElement el && el.DataContext is Device device)
        {
            var dlg = new SendDialog(this, device);
            await dlg.ShowAsync();
        }
    }

    private async void OnPendingPairingsChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (e.NewItems is null) return;
        foreach (var obj in e.NewItems)
        {
            if (obj is PendingPairing pp)
            {
                var dlg = new PairingDialog(this, pp);
                await dlg.ShowAsync();
            }
        }
    }

    private async void OnPendingOffersChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        if (e.NewItems is null) return;
        foreach (var obj in e.NewItems)
        {
            if (obj is PendingFileOffer offer)
            {
                var dlg = new FileOfferDialog(this, offer);
                await dlg.ShowAsync();
            }
        }
    }

    private void ClearHistory_Click(object sender, RoutedEventArgs e)
    {
        ViewModel.Engine.ClearHistory();
    }

    // ─── x:Bind 辅助方法 ───────────────────────────────────────────────

    public Visibility EmptyVisibility(int count) => count == 0 ? Visibility.Visible : Visibility.Collapsed;
    public Visibility HistoryVisibility(int count) => count > 0 ? Visibility.Visible : Visibility.Collapsed;

    public string DirectionLabel(TransferDirection d) => d == TransferDirection.Outgoing ? "发送到" : "来自";

    public Brush DirectionColor(TransferDirection d) =>
        new SolidColorBrush(d == TransferDirection.Outgoing
            ? Colors.DodgerBlue
            : Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x22, 0xC5, 0x5E));

    public string ContentSummary(HistoryKind kind) => kind switch
    {
        HistoryKind.Text t => t.Content,
        HistoryKind.File f => $"📄 {f.Name} ({ByteFormat.Format(f.Size)})",
        _ => "",
    };

    public string StatusLabel(TransferStatus s) => s switch
    {
        TransferStatus.Pending => "准备中…",
        TransferStatus.WaitingApproval => "等待对方接受…",
        TransferStatus.Transferring t => $"{ByteFormat.Format(t.BytesDone)} / {ByteFormat.Format(t.BytesTotal)}",
        TransferStatus.Completed => "✓ 完成",
        TransferStatus.Failed f => $"✗ {f.Reason}",
        TransferStatus.Canceled => "已取消",
        _ => "",
    };

    public Brush StatusColor(TransferStatus s) => new SolidColorBrush(s switch
    {
        TransferStatus.Completed => Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x22, 0xC5, 0x5E),
        TransferStatus.Failed => Colors.Crimson,
        _ => Microsoft.UI.ColorHelper.FromArgb(0xFF, 0x80, 0x80, 0x80),
    });

    private void SetWindowIcon()
    {
        try
        {
            var hwnd = WindowNative.GetWindowHandle(this);
            var windowId = Microsoft.UI.Win32Interop.GetWindowIdFromWindow(hwnd);
            var appWindow = Microsoft.UI.Windowing.AppWindow.GetFromWindowId(windowId);
            appWindow?.SetIcon(@"Assets\AppIcon.ico");
        }
        catch { }
    }
}
