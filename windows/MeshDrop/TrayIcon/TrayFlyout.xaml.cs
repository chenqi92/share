using System;
using System.Collections.ObjectModel;
using Microsoft.UI.Xaml;
using MeshDrop.Mock;
using MeshDrop.Transport;
using MeshDrop.ViewModels;

namespace MeshDrop.TrayIcon;

public sealed partial class TrayFlyout : Microsoft.UI.Xaml.Controls.UserControl
{
    public ObservableCollection<MockDevice> Devices { get; }

    public event EventHandler? OpenMainRequested;
    public event EventHandler? OpenSettingsRequested;

    public TrayFlyout()
    {
        Devices = new ProjectedCollection<MeshDrop.Models.Device, MockDevice>(
            ShareEngine.Shared.Devices, d => d.ToMock());
        InitializeComponent();
    }

    private void OpenMain_Click(object sender, RoutedEventArgs e) => OpenMainRequested?.Invoke(this, EventArgs.Empty);
    private void OpenSettings_Click(object sender, RoutedEventArgs e) => OpenSettingsRequested?.Invoke(this, EventArgs.Empty);
}
