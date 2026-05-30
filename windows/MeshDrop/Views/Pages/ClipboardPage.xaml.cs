using Microsoft.UI.Xaml;
using MeshDrop.ViewModels;
using Windows.ApplicationModel.DataTransfer;

namespace MeshDrop.Views.Pages;

public sealed partial class ClipboardPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public ClipboardViewModel ViewModel { get; }

    public ClipboardPage()
    {
        ViewModel = new ClipboardViewModel();
        InitializeComponent();
    }

    private void OnCopy_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement fe && fe.Tag is string content)
        {
            var pkg = new DataPackage();
            pkg.SetText(content);
            Clipboard.SetContent(pkg);
        }
    }
}
