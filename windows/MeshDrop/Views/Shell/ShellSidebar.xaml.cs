using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using MeshDrop.ViewModels;

namespace MeshDrop.Views.Shell;

public sealed partial class ShellSidebar : Microsoft.UI.Xaml.Controls.UserControl
{
    public ShellViewModel ViewModel { get; }

    public event EventHandler<ShellSection>? SectionChanged;
    public event EventHandler<string>? PeerChosen;

    public ShellSidebar()
    {
        ViewModel = new ShellViewModel();
        InitializeComponent();
        ApplyStrings();
    }

    public ShellSidebar(ShellViewModel vm)
    {
        ViewModel = vm;
        InitializeComponent();
        ApplyStrings();
    }

    // 自定义控件（ChipControl / AsciiDivider）的 DP 不能用 x:Uid 自动取串，统一在此设置。
    private void ApplyStrings()
    {
        TransfersBadge.Text = I18n.T("shell.nav.transfersBadge.Text");
        PairedDivider.Label = I18n.T("shell.pairedDivider");
    }

    private void OnDiscovery_Click(object sender, RoutedEventArgs e) => SectionChanged?.Invoke(this, ShellSection.Discovery);
    private void OnChat_Click(object sender, RoutedEventArgs e) => SectionChanged?.Invoke(this, ShellSection.Chat);
    private void OnTransfers_Click(object sender, RoutedEventArgs e) => SectionChanged?.Invoke(this, ShellSection.Transfers);
    private void OnHistory_Click(object sender, RoutedEventArgs e) => SectionChanged?.Invoke(this, ShellSection.History);
    private void OnClipboard_Click(object sender, RoutedEventArgs e) => SectionChanged?.Invoke(this, ShellSection.Clipboard);
    private void OnTrust_Click(object sender, RoutedEventArgs e) => SectionChanged?.Invoke(this, ShellSection.Trust);
    private void OnSettings_Click(object sender, RoutedEventArgs e) => SectionChanged?.Invoke(this, ShellSection.Settings);

    private void OnPeer_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement fe && fe.Tag is string id)
        {
            PeerChosen?.Invoke(this, id);
        }
    }
}
