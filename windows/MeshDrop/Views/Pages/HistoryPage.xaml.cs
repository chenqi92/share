using MeshDrop.Mock;
using MeshDrop.ViewModels;
using Microsoft.UI.Xaml;
using Windows.ApplicationModel.DataTransfer;

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

    // 剪贴板条目「复制」：把正文写回系统剪贴板。按钮 DataContext 即该行 MockClipboard。
    private void OnClipboardCopyClick(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement fe || fe.DataContext is not MockClipboard item) return;
        var dp = new DataPackage();
        dp.SetText(item.Body ?? "");
        Clipboard.SetContent(dp);
    }
}
