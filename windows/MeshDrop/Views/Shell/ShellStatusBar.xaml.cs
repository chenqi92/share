using Microsoft.UI.Xaml;
using MeshDrop.Transport;

namespace MeshDrop.Views.Shell;

public sealed partial class ShellStatusBar : Microsoft.UI.Xaml.Controls.UserControl
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    public ShellStatusBar()
    {
        InitializeComponent();
        Loaded += (_, _) => { Refresh(); Subscribe(); };
        Unloaded += (_, _) => Unsubscribe();
    }

    private void Subscribe()
    {
        _engine.PropertyChanged += OnEngineChanged;
        _engine.Devices.CollectionChanged += OnDevicesChanged;
    }

    private void Unsubscribe()
    {
        _engine.PropertyChanged -= OnEngineChanged;
        _engine.Devices.CollectionChanged -= OnDevicesChanged;
    }

    private void OnEngineChanged(object? sender, System.ComponentModel.PropertyChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(Refresh);
    }

    private void OnDevicesChanged(object? sender, System.Collections.Specialized.NotifyCollectionChangedEventArgs e)
    {
        DispatcherQueue.TryEnqueue(Refresh);
    }

    private void Refresh()
    {
        IpLabel.Text = _engine.LocalIp;
        PeerCountLabel.Text = $"{_engine.Devices.Count} PEERS";
        DisplayNameLabel.Text = _engine.DisplayName;

        if (_engine.IsStarting)
        {
            StateLabel.Text = "SCANNING";
            StateLabel.Foreground = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["MdSkyBrush"];
            StatusDot.Fill = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["MdSkyBrush"];
        }
        else if (_engine.IsRunning)
        {
            StateLabel.Text = "ONLINE";
            StateLabel.Foreground = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["MdLimeDeepBrush"];
            StatusDot.Fill = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["MdLimeDeepBrush"];
        }
        else
        {
            StateLabel.Text = "OFFLINE";
            StateLabel.Foreground = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["MdFlameBrush"];
            StatusDot.Fill = (Microsoft.UI.Xaml.Media.Brush)Application.Current.Resources["MdFlameBrush"];
        }

        if (_engine.LastError is { } err && !string.IsNullOrEmpty(err))
        {
            ErrorLabel.Text = $"⚠ {err}";
            ErrorLabel.Visibility = Visibility.Visible;
        }
        else
        {
            ErrorLabel.Visibility = Visibility.Collapsed;
        }
    }
}
