using System;
using MeshDrop.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MeshDrop.Views.Pages;

public sealed partial class SettingsPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public SettingsViewModel ViewModel { get; }

    public SettingsPage()
    {
        ViewModel = new SettingsViewModel();
        InitializeComponent();
    }

    private async void OnOpenReceiveFolder(object sender, RoutedEventArgs e)
    {
        try
        {
            System.IO.Directory.CreateDirectory(ViewModel.ReceiveDir);
            await Windows.System.Launcher.LaunchFolderPathAsync(ViewModel.ReceiveDir);
        }
        catch (System.Exception ex)
        {
            var dialog = new ContentDialog
            {
                Title = I18n.T("settings.openFolder"),
                Content = ex.Message,
                CloseButtonText = I18n.T("common.cancel.Text"),
                XamlRoot = XamlRoot,
            };
            await dialog.ShowAsync();
        }
    }

    private async void OnResetIdentityClick(object sender, RoutedEventArgs e)
    {
        await ViewModel.ResetIdentityCommand.ExecuteAsync(this.XamlRoot);
    }
}
