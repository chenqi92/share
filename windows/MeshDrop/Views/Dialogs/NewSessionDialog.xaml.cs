using System.Collections.ObjectModel;
using MeshDrop.Mock;
using MeshDrop.Transport;
using MeshDrop.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace MeshDrop.Views.Dialogs;

/// <summary>
/// 「+ 新会话」/「发送文件」目标设备选择对话框。列出引擎当前发现的设备（快照），
/// 用户单选后由 <see cref="SelectedPeerId"/> 回传对端 Id；未选中时主按钮禁用。
/// </summary>
public sealed partial class NewSessionDialog : ContentDialog
{
    /// <summary>对话框展示的设备快照（构造时从 ShareEngine.Devices 投影）。</summary>
    public ObservableCollection<MockDevice> Devices { get; } = new();

    /// <summary>用户选中的对端 Id；未选返回空串。</summary>
    public string SelectedPeerId { get; private set; } = "";

    public NewSessionDialog() : this(null) { }

    /// <param name="primaryText">主按钮文案；null 时用「开始会话」。发送文件流程传「发送」。</param>
    public NewSessionDialog(string? primaryText)
    {
        InitializeComponent();

        Title = I18n.T("newSession.title");
        PrimaryButtonText = primaryText ?? I18n.T("newSession.start");
        CloseButtonText = I18n.T("common.cancel");
        EmptyTitle.Text = I18n.T("newSession.emptyTitle");
        EmptyHint.Text = I18n.T("newSession.emptyHint");

        foreach (var d in ShareEngine.Shared.Devices)
            Devices.Add(d.ToMock());
        DeviceList.ItemsSource = Devices;

        var hasDevices = Devices.Count > 0;
        DeviceList.Visibility = hasDevices ? Visibility.Visible : Visibility.Collapsed;
        EmptyPanel.Visibility = hasDevices ? Visibility.Collapsed : Visibility.Visible;
        IsPrimaryButtonEnabled = false; // 需先选中一台设备
    }

    private void OnSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (DeviceList.SelectedItem is MockDevice d)
        {
            SelectedPeerId = d.Id;
            IsPrimaryButtonEnabled = true;
        }
        else
        {
            SelectedPeerId = "";
            IsPrimaryButtonEnabled = false;
        }
    }
}
