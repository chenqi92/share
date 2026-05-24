using MeshDrop.Models;
using MeshDrop.Transport;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace MeshDrop.Views;

/// <summary>
/// 配对确认对话框：显示指纹，三选项（拒绝 / 允许一次 / 允许并记住）。
/// </summary>
public sealed class PairingDialog : ContentDialog
{
    public PairingDialog(Window window, PendingPairing pending)
    {
        var engine = ShareEngine.Shared;
        XamlRoot = window.Content.XamlRoot;
        Title = $"{pending.Peer.Name} 想要连接";

        PrimaryButtonText = "允许并记住";
        SecondaryButtonText = "允许一次";
        CloseButtonText = "拒绝";
        DefaultButton = ContentDialogButton.Primary;

        var root = new StackPanel { Spacing = 10, Width = 420 };
        root.Children.Add(new TextBlock
        {
            Text = "请确认指纹与对方设备上显示的完全一致。",
            Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray),
            TextWrapping = TextWrapping.Wrap,
        });
        root.Children.Add(new TextBlock
        {
            Text = pending.Peer.HumanFingerprint,
            FontFamily = new FontFamily("Cascadia Mono"),
            FontSize = 16,
            FontWeight = FontWeights.Medium,
            IsTextSelectionEnabled = true,
            Padding = new Thickness(12),
        });
        Content = root;

        PrimaryButtonClick += (_, __) => engine.RespondToPairing(pending.Id, PairingDecision.Trust);
        SecondaryButtonClick += (_, __) => engine.RespondToPairing(pending.Id, PairingDecision.AllowOnce);
        CloseButtonClick += (_, __) => engine.RespondToPairing(pending.Id, PairingDecision.Reject);
    }
}
