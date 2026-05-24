using Microsoft.UI.Xaml;

namespace MeshDrop.Views.Controls;

public sealed partial class AsciiDivider : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty LabelProperty = DependencyProperty.Register(
        nameof(Label), typeof(string), typeof(AsciiDivider), new PropertyMetadata("── SECTION ──"));

    public string Label
    {
        get => (string)GetValue(LabelProperty);
        set => SetValue(LabelProperty, value);
    }

    public AsciiDivider()
    {
        InitializeComponent();
    }
}
