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
        // 自定义控件（ChipControl / DashTile / AsciiDivider）的 DP 不走 x:Uid，在此设置。
        FilterAll.Text = I18n.T("transfers.filterAll.Text");
        FilterActive.Text = I18n.T("transfers.filterActive.Text");
        FilterDone.Text = I18n.T("transfers.filterDone.Text");
        SessionTile.Label = I18n.T("transfers.tileSession");
        UpTile.Label = I18n.T("transfers.tileUp");
        DownTile.Label = I18n.T("transfers.tileDown");
        TasksDivider.Label = I18n.T("transfers.tasksDivider");
    }

    private void OnRowCancelRequested(object sender, EventArgs e)
    {
        if (sender is TransferRowControl row && row.Tag is MockTransfer item)
        {
            ViewModel.CancelCommand.Execute(item);
        }
    }
}
