using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class SettingsPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public SettingsViewModel ViewModel { get; }

    public SettingsPage()
    {
        ViewModel = new SettingsViewModel();
        InitializeComponent();
    }
}
