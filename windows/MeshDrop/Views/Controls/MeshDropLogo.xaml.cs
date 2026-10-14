using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;

namespace MeshDrop.Views.Controls;

public sealed partial class MeshDropLogo : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty SizeProperty = DependencyProperty.Register(
        nameof(Size), typeof(double), typeof(MeshDropLogo), new PropertyMetadata(28.0));

    public double Size
    {
        get => (double)GetValue(SizeProperty);
        set => SetValue(SizeProperty, value);
    }

    public MeshDropLogo()
    {
        InitializeComponent();
    }
}
