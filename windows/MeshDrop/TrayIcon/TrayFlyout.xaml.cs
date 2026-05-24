using System;
using System.Collections.Generic;
using Microsoft.UI.Xaml;
using MeshDrop.Mock;

namespace MeshDrop.TrayIcon;

public sealed partial class TrayFlyout : Microsoft.UI.Xaml.Controls.UserControl
{
    public IReadOnlyList<MockDevice> Devices { get; } = MockData.Devices;

    public event EventHandler? OpenMainRequested;
    public event EventHandler? OpenSettingsRequested;

    public TrayFlyout()
    {
        InitializeComponent();
    }

    private void OpenMain_Click(object sender, RoutedEventArgs e) => OpenMainRequested?.Invoke(this, EventArgs.Empty);
    private void OpenSettings_Click(object sender, RoutedEventArgs e) => OpenSettingsRequested?.Invoke(this, EventArgs.Empty);
}
