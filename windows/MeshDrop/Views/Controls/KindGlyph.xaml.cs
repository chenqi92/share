using Microsoft.UI.Xaml;
using MeshDrop.Mock;

namespace MeshDrop.Views.Controls;

public sealed partial class KindGlyph : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty SizeProperty = DependencyProperty.Register(
        nameof(Size), typeof(double), typeof(KindGlyph), new PropertyMetadata(12.0));

    public static readonly DependencyProperty KindProperty = DependencyProperty.Register(
        nameof(Kind), typeof(MockKind), typeof(KindGlyph),
        new PropertyMetadata(MockKind.Mac, (d, _) => ((KindGlyph)d).Apply()));

    public double Size { get => (double)GetValue(SizeProperty); set => SetValue(SizeProperty, value); }
    public MockKind Kind { get => (MockKind)GetValue(KindProperty); set => SetValue(KindProperty, value); }

    public KindGlyph()
    {
        InitializeComponent();
        Loaded += (_, _) => Apply();
    }

    private void Apply()
    {
        if (MacPath is null) return;
        MacPath.Visibility = Kind == MockKind.Mac ? Visibility.Visible : Visibility.Collapsed;
        WinPath.Visibility = Kind == MockKind.Win ? Visibility.Visible : Visibility.Collapsed;
        IpadPath.Visibility = Kind == MockKind.Ipad ? Visibility.Visible : Visibility.Collapsed;
        IpadDot.Visibility = Kind == MockKind.Ipad ? Visibility.Visible : Visibility.Collapsed;
        PhonePath.Visibility = (Kind == MockKind.Ios || Kind == MockKind.Android) ? Visibility.Visible : Visibility.Collapsed;
        LinuxPath.Visibility = Kind == MockKind.Linux ? Visibility.Visible : Visibility.Collapsed;
    }
}
