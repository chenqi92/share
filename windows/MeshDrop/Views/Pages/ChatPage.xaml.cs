using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class ChatPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public ChatViewModel ViewModel { get; }

    public ChatPage()
    {
        ViewModel = new ChatViewModel();
        InitializeComponent();
    }
}
