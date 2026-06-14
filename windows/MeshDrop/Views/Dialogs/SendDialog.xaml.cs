using Microsoft.UI.Xaml.Controls;

namespace MeshDrop.Views.Dialogs;

public sealed partial class SendDialog : ContentDialog
{
    public SendDialog()
    {
        InitializeComponent();
        CloseButtonText = I18n.T("send.cancel");
        PrimaryButtonText = I18n.T("send.send");
        PlaintextChip.Text = I18n.T("send.chipPlaintext.Text");
        KindDivider.Label = I18n.T("send.kindDivider");
    }
}
