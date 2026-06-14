using Microsoft.UI.Xaml;
using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class DiscoveryPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public DiscoveryViewModel ViewModel { get; }

    public DiscoveryPage()
    {
        ViewModel = new DiscoveryViewModel();
        InitializeComponent();
        // 自定义 ChipControl 的 Text DP 不走 x:Uid，在此设置本地化串。
        LiveChip.Text = I18n.T("discovery.chipLive");
        PlaintextChip.Text = I18n.T("discovery.chipPlaintext");
        LanOnlyChip.Text = I18n.T("discovery.chipLanOnly");
        Loaded += (_, _) => { Refresh(); ViewModel.PropertyChanged += OnVmChanged; ViewModel.Devices.CollectionChanged += OnDevicesChanged; };
        Unloaded += (_, _) => { ViewModel.PropertyChanged -= OnVmChanged; ViewModel.Devices.CollectionChanged -= OnDevicesChanged; };
    }

    private void OnVmChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(Refresh);
    }

    private void OnDevicesChanged(object? sender, System.Collections.Specialized.NotifyCollectionChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(Refresh);
    }

    private void Refresh()
    {
        ScanningBanner.Visibility = ViewModel.IsScanning && ViewModel.Devices.Count == 0
            ? Visibility.Visible : Visibility.Collapsed;

        if (ViewModel.LastError is { } err && !string.IsNullOrEmpty(err))
        {
            ErrorText.Text = I18n.T("discovery.networkErrorFormat", err);
            ErrorBanner.Visibility = Visibility.Visible;
        }
        else
        {
            ErrorBanner.Visibility = Visibility.Collapsed;
        }

        EmptyCard.Visibility = ViewModel.IsEmpty ? Visibility.Visible : Visibility.Collapsed;
        // 雷达页脚分隔条：含可读词（扫描/脉冲/台数），整体走本地化模板，{0} 为设备数。
        FooterDivider.Label = I18n.T("discovery.sweepFooterFormat", ViewModel.Devices.Count);
    }
}
