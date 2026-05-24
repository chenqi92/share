using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class HistoryPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public HistoryViewModel ViewModel { get; }

    public HistoryPage()
    {
        ViewModel = new HistoryViewModel();
        InitializeComponent();
    }
}
