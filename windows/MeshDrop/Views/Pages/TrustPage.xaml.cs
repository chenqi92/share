using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class TrustPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public TrustViewModel ViewModel { get; }

    public TrustPage()
    {
        ViewModel = new TrustViewModel();
        InitializeComponent();
    }
}
