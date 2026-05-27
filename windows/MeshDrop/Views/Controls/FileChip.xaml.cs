using Microsoft.UI.Xaml;

namespace MeshDrop.Views.Controls;

public sealed partial class FileChip : Microsoft.UI.Xaml.Controls.UserControl
{
    // 显式 'new' 隐藏 FrameworkElement.NameProperty —— 这是我们 UserControl 自己的属性
    public static new readonly DependencyProperty NameProperty = DependencyProperty.Register(
        nameof(Name), typeof(string), typeof(FileChip), new PropertyMetadata(""));

    public static readonly DependencyProperty SizeProperty = DependencyProperty.Register(
        nameof(Size), typeof(string), typeof(FileChip), new PropertyMetadata(""));

    public static readonly DependencyProperty ExtProperty = DependencyProperty.Register(
        nameof(Ext), typeof(string), typeof(FileChip), new PropertyMetadata(""));

    public static readonly DependencyProperty ProgressProperty = DependencyProperty.Register(
        nameof(Progress), typeof(double), typeof(FileChip),
        new PropertyMetadata(0.0, (d, _) => ((FileChip)d).RefreshVisibility()));

    public static readonly DependencyProperty ProgressVisibilityProperty = DependencyProperty.Register(
        nameof(ProgressVisibility), typeof(Visibility), typeof(FileChip),
        new PropertyMetadata(Visibility.Collapsed));

    public new string Name { get => (string)GetValue(NameProperty); set => SetValue(NameProperty, value); }
    public string Size { get => (string)GetValue(SizeProperty); set => SetValue(SizeProperty, value); }
    public string Ext { get => (string)GetValue(ExtProperty); set => SetValue(ExtProperty, value); }
    public double Progress { get => (double)GetValue(ProgressProperty); set => SetValue(ProgressProperty, value); }
    public Visibility ProgressVisibility
    {
        get => (Visibility)GetValue(ProgressVisibilityProperty);
        set => SetValue(ProgressVisibilityProperty, value);
    }

    public FileChip()
    {
        InitializeComponent();
        RefreshVisibility();
    }

    private void RefreshVisibility()
    {
        ProgressVisibility = Progress > 0 && Progress < 100 ? Visibility.Visible : Visibility.Collapsed;
    }
}
