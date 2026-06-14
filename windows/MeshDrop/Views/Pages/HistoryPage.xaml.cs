using MeshDrop.ViewModels;

namespace MeshDrop.Views.Pages;

public sealed partial class HistoryPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public HistoryViewModel ViewModel { get; }

    public HistoryPage()
    {
        ViewModel = new HistoryViewModel();
        InitializeComponent();
        // 自定义控件（ChipControl / AsciiDivider）的 DP 不走 x:Uid，在此设置。
        FilterAll.Text = I18n.T("history.filterAll.Text");
        FilterFile.Text = I18n.T("history.filterFile.Text");
        FilterImage.Text = I18n.T("history.filterImage.Text");
        FilterText.Text = I18n.T("history.filterText.Text");
        ClipboardDivider.Label = I18n.T("history.clipboardDivider");
        TodayDivider.Label = I18n.T("history.todayDivider");
    }
}
