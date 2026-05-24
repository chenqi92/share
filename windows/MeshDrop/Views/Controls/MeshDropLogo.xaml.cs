using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;

namespace MeshDrop.Views.Controls;

public sealed partial class MeshDropLogo : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty SizeProperty = DependencyProperty.Register(
        nameof(Size), typeof(double), typeof(MeshDropLogo), new PropertyMetadata(28.0));

    public static readonly DependencyProperty RingBrushProperty = DependencyProperty.Register(
        nameof(RingBrush), typeof(Brush), typeof(MeshDropLogo),
        new PropertyMetadata(new SolidColorBrush(Microsoft.UI.Colors.White)));

    public double Size
    {
        get => (double)GetValue(SizeProperty);
        set => SetValue(SizeProperty, value);
    }

    public Brush RingBrush
    {
        get => (Brush)GetValue(RingBrushProperty);
        set => SetValue(RingBrushProperty, value);
    }

    public MeshDropLogo()
    {
        InitializeComponent();
        if (Resources.TryGetValue("MdInkBrush", out var b) && b is Brush br)
        {
            RingBrush = br;
        }
    }
}
