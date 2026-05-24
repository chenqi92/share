using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class DiscoveryPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public DiscoveryViewModel ViewModel { get; }

    public DiscoveryPage()
    {
        ViewModel = new DiscoveryViewModel();
        InitializeComponent();
    }
}
