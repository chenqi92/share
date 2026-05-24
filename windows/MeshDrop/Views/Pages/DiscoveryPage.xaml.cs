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
            ErrorText.Text = $"网络出错 — {err}";
            ErrorBanner.Visibility = Visibility.Visible;
        }
        else
        {
            ErrorBanner.Visibility = Visibility.Collapsed;
        }

        EmptyCard.Visibility = ViewModel.IsEmpty ? Visibility.Visible : Visibility.Collapsed;
        FooterDivider.Label = $"── SWEEP 4.5s · PULSE 2.6s · {ViewModel.Devices.Count} PEERS ──";
    }
}
