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

    private async void OnResetIdentityClick(object sender, RoutedEventArgs e)
    {
        await ViewModel.ResetIdentityCommand.ExecuteAsync(this.XamlRoot);
    }
}
