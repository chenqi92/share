using MeshDrop.Models;
using MeshDrop.Transport;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace MeshDrop.Views;

public sealed class FileOfferDialog : ContentDialog
{
    public FileOfferDialog(Window window, PendingFileOffer offer)
    {
        var engine = ShareEngine.Shared;
        XamlRoot = window.Content.XamlRoot;
        Title = $"{offer.Peer.Name} 想发送文件";

        PrimaryButtonText = "接受";
        CloseButtonText = "拒绝";
        DefaultButton = ContentDialogButton.Primary;

        var root = new StackPanel { Spacing = 8, Width = 380 };
        root.Children.Add(new TextBlock
        {
            Text = "接受后将保存到 Documents/MeshDrop 文件夹",
            Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray),
            TextWrapping = TextWrapping.Wrap,
        });
        root.Children.Add(new TextBlock
        {
            Text = offer.FileName,
            FontWeight = FontWeights.SemiBold,
            FontSize = 15,
        });
        root.Children.Add(new TextBlock
        {
            Text = offer.FormattedSize,
            Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray),
            FontSize = 12,
        });
        Content = root;

        PrimaryButtonClick += (_, __) => engine.RespondToFileOffer(offer.Id, accept: true);
        CloseButtonClick += (_, __) => engine.RespondToFileOffer(offer.Id, accept: false);
    }
}
