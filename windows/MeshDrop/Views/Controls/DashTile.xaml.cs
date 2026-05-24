using System.Collections.Generic;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace MeshDrop.Views.Controls;

public sealed partial class DashTile : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty LabelProperty = DependencyProperty.Register(
        nameof(Label), typeof(string), typeof(DashTile), new PropertyMetadata("LABEL"));

    public static readonly DependencyProperty ValueProperty = DependencyProperty.Register(
        nameof(Value), typeof(string), typeof(DashTile), new PropertyMetadata("0"));

    public static readonly DependencyProperty HintProperty = DependencyProperty.Register(
        nameof(Hint), typeof(string), typeof(DashTile), new PropertyMetadata(""));

    public static readonly DependencyProperty AccentBrushProperty = DependencyProperty.Register(
        nameof(AccentBrush), typeof(Brush), typeof(DashTile),
        new PropertyMetadata(new SolidColorBrush(Microsoft.UI.Colors.LimeGreen), (d, _) => ((DashTile)d).RebuildBars()));

    public static readonly DependencyProperty BarsProperty = DependencyProperty.Register(
        nameof(Bars), typeof(IReadOnlyList<int>), typeof(DashTile),
        new PropertyMetadata(null, (d, _) => ((DashTile)d).RebuildBars()));

    public string Label { get => (string)GetValue(LabelProperty); set => SetValue(LabelProperty, value); }
    public string Value { get => (string)GetValue(ValueProperty); set => SetValue(ValueProperty, value); }
    public string Hint { get => (string)GetValue(HintProperty); set => SetValue(HintProperty, value); }
    public Brush AccentBrush { get => (Brush)GetValue(AccentBrushProperty); set => SetValue(AccentBrushProperty, value); }
    public IReadOnlyList<int>? Bars { get => (IReadOnlyList<int>?)GetValue(BarsProperty); set => SetValue(BarsProperty, value); }

    public DashTile()
    {
        InitializeComponent();
        Loaded += (_, _) => RebuildBars();
    }

    private void RebuildBars()
    {
        if (BarsHost is null) return;
        BarsHost.Children.Clear();
        if (Bars is null) return;
        var brush = AccentBrush;
        foreach (var v in Bars)
        {
            var r = new Microsoft.UI.Xaml.Shapes.Rectangle
            {
                Width = 6,
                Height = System.Math.Max(2, v * 3),
                RadiusX = 1,
                RadiusY = 1,
                Fill = brush,
                VerticalAlignment = VerticalAlignment.Bottom,
            };
            BarsHost.Children.Add(r);
        }
    }
}
