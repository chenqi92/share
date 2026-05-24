using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class TransfersPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public TransfersViewModel ViewModel { get; }

    public TransfersPage()
    {
        ViewModel = new TransfersViewModel();
        InitializeComponent();
    }
}
