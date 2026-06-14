using MeshDrop.Models;
using MeshDrop.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace MeshDrop.Views.Dialogs;

/// <summary>
/// TOFU 配对审批对话框。用 <see cref="Decision"/> 回传用户选择，调用方据此调
/// ShareEngine.RespondToPairing。窗口在前台时由 MainWindow 弹出；否则走 Toast 路径。
/// </summary>
public sealed partial class PairingDialog : ContentDialog
{
    /// <summary>用户选择；未选择（外部关闭）时为 null。</summary>
    public PairingDecision? Decision { get; private set; }

    public PairingDialog(PendingPairingVM pairing)
    {
        InitializeComponent();
        CompareDivider.Label = I18n.T("pairing.compareDivider");
        PeerLine.Text = $"{pairing.Who} · {pairing.DeviceName}";
        FingerprintText.Text = pairing.Fingerprint;
    }

    private void OnTrust(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        Decision = PairingDecision.Trust;
        Hide();
    }

    private void OnAllowOnce(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        Decision = PairingDecision.AllowOnce;
        Hide();
    }

    private void OnReject(object sender, Microsoft.UI.Xaml.RoutedEventArgs e)
    {
        Decision = PairingDecision.Reject;
        Hide();
    }
}
