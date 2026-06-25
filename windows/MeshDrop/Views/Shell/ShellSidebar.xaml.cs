using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
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
        SetActiveSection(ViewModel.Section);
    }

    public ShellSidebar(ShellViewModel vm)
    {
        ViewModel = vm;
        InitializeComponent();
        ApplyStrings();
        SetActiveSection(ViewModel.Section);
    }

    // 自定义控件（ChipControl / AsciiDivider）的 DP 不能用 x:Uid 自动取串，统一在此设置。
    private void ApplyStrings()
    {
        TransfersBadge.Text = I18n.T("shell.nav.transfersBadge.Text");
        PairedDivider.Label = I18n.T("shell.pairedDivider");
    }

    private void OnDiscovery_Click(object sender, RoutedEventArgs e) => Navigate(ShellSection.Discovery);
    private void OnChat_Click(object sender, RoutedEventArgs e) => Navigate(ShellSection.Chat);
    private void OnTransfers_Click(object sender, RoutedEventArgs e) => Navigate(ShellSection.Transfers);
    private void OnHistory_Click(object sender, RoutedEventArgs e) => Navigate(ShellSection.History);
    private void OnClipboard_Click(object sender, RoutedEventArgs e) => Navigate(ShellSection.Clipboard);
    private void OnTrust_Click(object sender, RoutedEventArgs e) => Navigate(ShellSection.Trust);
    private void OnSettings_Click(object sender, RoutedEventArgs e) => Navigate(ShellSection.Settings);

    // 高亮当前页并向上抛事件；点击对端进入 Chat 时同样把 Chat 标成 active。
    private void Navigate(ShellSection section)
    {
        SetActiveSection(section);
        SectionChanged?.Invoke(this, section);
    }

    private void OnPeer_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement fe && fe.Tag is string id)
        {
            SetActiveSection(ShellSection.Chat);
            PeerChosen?.Invoke(this, id);
        }
    }

    // 由外部（如 MainWindow 经托盘菜单跳转）也可调用，保持侧栏高亮与当前页一致。
    public void SetActiveSection(ShellSection section)
    {
        ApplyNav(NavDiscovery, NavDiscoveryLabel, section == ShellSection.Discovery);
        ApplyNav(NavChat, NavChatLabel, section == ShellSection.Chat);
        ApplyNav(NavTransfers, NavTransfersLabel, section == ShellSection.Transfers);
        ApplyNav(NavHistory, NavHistoryLabel, section == ShellSection.History);
        ApplyNav(NavClipboard, NavClipboardLabel, section == ShellSection.Clipboard);
        ApplyNav(NavTrust, NavTrustLabel, section == ShellSection.Trust);
        ApplyNav(NavSettings, NavSettingsLabel, section == ShellSection.Settings);
    }

    // 统一规范选中态：lime@32%/16% 填充 + 1px lime 描边 + 选中标签用主文字色并加重；
    // 未选中恢复透明背景、无描边、次文字色。所有画刷取自主题字典，自动跟随 light/dark。
    private void ApplyNav(Button button, TextBlock label, bool active)
    {
        if (active)
        {
            button.Background = Lookup("MdLimeFillBrush");
            button.BorderBrush = Lookup("MdLimeBrush");
            button.BorderThickness = new Thickness(1);
            label.Foreground = Lookup("MdInkBrush");
            label.FontWeight = Microsoft.UI.Text.FontWeights.SemiBold;
        }
        else
        {
            button.Background = new SolidColorBrush(Microsoft.UI.Colors.Transparent);
            button.BorderThickness = new Thickness(0);
            label.Foreground = Lookup("MdInk60Brush");
            label.FontWeight = Microsoft.UI.Text.FontWeights.Normal;
        }
    }

    // 画刷 key 定义在 MeshDropColors.xaml 的 ThemeDictionaries(Light/Dark)里。
    // Application.Current.Resources[key] 这个扁平索引器解析不到 ThemeDictionaries 内的 key
    // （且缺 key 会抛 KeyNotFoundException），所以这里递归走主题字典 + 合并字典，找不到时回落透明，绝不抛。
    private static Brush Lookup(string key)
        => FindBrush(Application.Current.Resources, key) ?? new SolidColorBrush(Microsoft.UI.Colors.Transparent);

    private static Brush? FindBrush(ResourceDictionary dict, string key)
    {
        if (dict is null) return null;
        if (dict.ContainsKey(key) && dict[key] is Brush b) return b;

        var theme = Application.Current.RequestedTheme == ApplicationTheme.Light ? "Light" : "Dark";
        if (dict.ThemeDictionaries.TryGetValue(theme, out var active) && active is ResourceDictionary ad)
        {
            var r = FindBrush(ad, key);
            if (r is not null) return r;
        }
        foreach (var kv in dict.ThemeDictionaries)
            if (kv.Value is ResourceDictionary td)
            {
                var r = FindBrush(td, key);
                if (r is not null) return r;
            }
        foreach (var md in dict.MergedDictionaries)
        {
            var r = FindBrush(md, key);
            if (r is not null) return r;
        }
        return null;
    }
}
