using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Windows.UI;

namespace MeshDrop.Views.Controls;

public sealed partial class AvatarControl : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty SizeProperty = DependencyProperty.Register(
        nameof(Size), typeof(double), typeof(AvatarControl),
        new PropertyMetadata(32.0, OnAnyChanged));

    public static readonly DependencyProperty InitialsProperty = DependencyProperty.Register(
        nameof(Initials), typeof(string), typeof(AvatarControl), new PropertyMetadata("?"));

    public static readonly DependencyProperty ColorHexProperty = DependencyProperty.Register(
        nameof(ColorHex), typeof(string), typeof(AvatarControl),
        new PropertyMetadata("#FFB4A1", OnColorChanged));

    public static readonly DependencyProperty ShowRingProperty = DependencyProperty.Register(
        nameof(ShowRing), typeof(Visibility), typeof(AvatarControl),
        new PropertyMetadata(Visibility.Collapsed));

    public static readonly DependencyProperty FillBrushProperty = DependencyProperty.Register(
        nameof(FillBrush), typeof(Brush), typeof(AvatarControl),
        new PropertyMetadata(new SolidColorBrush(Color.FromArgb(0xFF, 0xFF, 0xB4, 0xA1))));

    public static readonly DependencyProperty InitialsSizeProperty = DependencyProperty.Register(
        nameof(InitialsSize), typeof(double), typeof(AvatarControl),
        new PropertyMetadata(12.0));

    public double Size { get => (double)GetValue(SizeProperty); set => SetValue(SizeProperty, value); }
    public string Initials { get => (string)GetValue(InitialsProperty); set => SetValue(InitialsProperty, value); }
    public string ColorHex { get => (string)GetValue(ColorHexProperty); set => SetValue(ColorHexProperty, value); }
    public Visibility ShowRing { get => (Visibility)GetValue(ShowRingProperty); set => SetValue(ShowRingProperty, value); }
    public Brush FillBrush { get => (Brush)GetValue(FillBrushProperty); set => SetValue(FillBrushProperty, value); }
    public double InitialsSize { get => (double)GetValue(InitialsSizeProperty); set => SetValue(InitialsSizeProperty, value); }

    public AvatarControl()
    {
        InitializeComponent();
        UpdateBrush();
        UpdateInitialsSize();
    }

    private static void OnAnyChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is AvatarControl a) a.UpdateInitialsSize();
    }

    private static void OnColorChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is AvatarControl a) a.UpdateBrush();
    }

    private void UpdateBrush()
    {
        FillBrush = new SolidColorBrush(ParseHex(ColorHex));
    }

    private void UpdateInitialsSize()
    {
        InitialsSize = System.Math.Max(9, Size * 0.42);
    }

    private static Color ParseHex(string hex)
    {
        if (string.IsNullOrEmpty(hex)) return Colors.LightGray;
        var s = hex.TrimStart('#');
        if (s.Length == 6) s = "FF" + s;
        if (s.Length != 8) return Colors.LightGray;
        return Color.FromArgb(
            System.Convert.ToByte(s.Substring(0, 2), 16),
            System.Convert.ToByte(s.Substring(2, 2), 16),
            System.Convert.ToByte(s.Substring(4, 2), 16),
            System.Convert.ToByte(s.Substring(6, 2), 16));
    }
}
