using System;
using MeshDrop.Mock;
using MeshDrop.ViewModels;
using MeshDrop.Views.Controls;

namespace MeshDrop.Views.Pages;

public sealed partial class TransfersPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public TransfersViewModel ViewModel { get; }

    public TransfersPage()
    {
        ViewModel = new TransfersViewModel();
        InitializeComponent();
    }

    private void OnRowCancelRequested(object sender, EventArgs e)
    {
        if (sender is TransferRowControl row && row.Tag is MockTransfer item)
        {
            ViewModel.CancelCommand.Execute(item);
        }
    }
}
