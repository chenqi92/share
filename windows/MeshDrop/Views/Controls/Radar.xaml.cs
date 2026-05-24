using System;
using System.Collections.Generic;
using Microsoft.UI;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Animation;
using Microsoft.UI.Xaml.Shapes;
using MeshDrop.Mock;
using Windows.UI;

namespace MeshDrop.Views.Controls;

public sealed partial class Radar : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty DiameterProperty = DependencyProperty.Register(
        nameof(Diameter), typeof(double), typeof(Radar),
        new PropertyMetadata(400.0, (d, _) => ((Radar)d).Rebuild()));

    public static readonly DependencyProperty DevicesProperty = DependencyProperty.Register(
        nameof(Devices), typeof(IReadOnlyList<MockDevice>), typeof(Radar),
        new PropertyMetadata(null, (d, _) => ((Radar)d).Rebuild()));

    public static readonly DependencyProperty SelectedIdProperty = DependencyProperty.Register(
        nameof(SelectedId), typeof(string), typeof(Radar),
        new PropertyMetadata(null, (d, _) => ((Radar)d).Rebuild()));

    public static readonly DependencyProperty VariantProperty = DependencyProperty.Register(
        nameof(Variant), typeof(string), typeof(Radar),
        new PropertyMetadata("sweep", (d, _) => ((Radar)d).Rebuild()));

    public double Diameter { get => (double)GetValue(DiameterProperty); set => SetValue(DiameterProperty, value); }
    public IReadOnlyList<MockDevice>? Devices { get => (IReadOnlyList<MockDevice>?)GetValue(DevicesProperty); set => SetValue(DevicesProperty, value); }
    public string? SelectedId { get => (string?)GetValue(SelectedIdProperty); set => SetValue(SelectedIdProperty, value); }
    public string Variant { get => (string)GetValue(VariantProperty); set => SetValue(VariantProperty, value); }

    private Storyboard? _sweepStory;

    public Radar()
    {
        InitializeComponent();
        Loaded += (_, _) =>
        {
            Rebuild();
            StartSweep();
        };
        Unloaded += (_, _) => _sweepStory?.Stop();
    }

    private void Rebuild()
    {
        if (GridLayer is null) return;

        var d = Diameter;
        Root.Width = d;
        Root.Height = d;
        var r = d / 2;

        // 同心圆尺寸
        Ring1.Width = Ring1.Height = d * 1.0 - 8;
        Ring2.Width = Ring2.Height = d * 0.66;
        Ring3.Width = Ring3.Height = d * 0.33;

        // 十字 + 罗盘
        CompassLayer.Children.Clear();
        var cross1 = new Line
        {
            X1 = 0, Y1 = r, X2 = d, Y2 = r,
            Stroke = (Brush)Application.Current.Resources["MdLineBrush"],
            StrokeThickness = 1,
            Opacity = 0.25,
            StrokeDashArray = new DoubleCollection { 2, 6 },
        };
        var cross2 = new Line
        {
            X1 = r, Y1 = 0, X2 = r, Y2 = d,
            Stroke = (Brush)Application.Current.Resources["MdLineBrush"],
            StrokeThickness = 1,
            Opacity = 0.25,
            StrokeDashArray = new DoubleCollection { 2, 6 },
        };
        CompassLayer.Children.Add(cross1);
        CompassLayer.Children.Add(cross2);

        foreach (var (label, dx, dy) in new (string, double, double)[]
        {
            ("N", r - 5, 6),
            ("E", d - 14, r - 7),
            ("S", r - 5, d - 18),
            ("W", 4, r - 7),
        })
        {
            var t = new TextBlock
            {
                Text = label,
                FontFamily = (FontFamily)Application.Current.Resources["MdMonoFontFamily"],
                FontSize = 9,
                Opacity = 0.45,
            };
            Canvas.SetLeft(t, dx);
            Canvas.SetTop(t, dy);
            CompassLayer.Children.Add(t);
        }

        // grid variant：在背景上撒点阵
        GridLayer.Children.Clear();
        if (Variant == "grid")
        {
            var step = 18;
            for (var x = 8; x < d - 8; x += step)
            for (var y = 8; y < d - 8; y += step)
            {
                var dx = x - r;
                var dy = y - r;
                if (System.Math.Sqrt(dx * dx + dy * dy) > r - 8) continue;
                var dot = new Ellipse
                {
                    Width = 2,
                    Height = 2,
                    Fill = new SolidColorBrush(Color.FromArgb(0x55, 0xDD, 0xF9, 0x4B)),
                };
                Canvas.SetLeft(dot, x);
                Canvas.SetTop(dot, y);
                GridLayer.Children.Add(dot);
            }
        }

        // Sweep 扇形（一条 lime 渐变线）
        SweepLayer.Children.Clear();
        SweepLayer.Width = d;
        SweepLayer.Height = d;
        SweepLayer.RenderTransformOrigin = new Windows.Foundation.Point(0.5, 0.5);

        var sweep = new Line
        {
            X1 = r, Y1 = r, X2 = r, Y2 = 8,
            StrokeThickness = 2,
            Stroke = new LinearGradientBrush
            {
                StartPoint = new Windows.Foundation.Point(0, 1),
                EndPoint = new Windows.Foundation.Point(0, 0),
                GradientStops =
                {
                    new GradientStop { Color = Color.FromArgb(0x00, 0xDD, 0xF9, 0x4B), Offset = 0 },
                    new GradientStop { Color = Color.FromArgb(0x60, 0xDD, 0xF9, 0x4B), Offset = 0.55 },
                    new GradientStop { Color = Color.FromArgb(0xFF, 0xDD, 0xF9, 0x4B), Offset = 1.0 },
                },
            },
        };
        SweepLayer.Children.Add(sweep);

        // 设备点
        DotsLayer.Children.Clear();
        DotsLayer.Width = d;
        DotsLayer.Height = d;
        if (Devices is null) return;

        var max = r - 24;
        foreach (var dev in Devices)
        {
            var rad = dev.Angle * System.Math.PI / 180.0;
            var dist = dev.Dist * max;
            var cx = r + System.Math.Cos(rad) * dist;
            var cy = r + System.Math.Sin(rad) * dist;

            // halo
            var selected = dev.Id == SelectedId;
            var haloColor = selected
                ? Color.FromArgb(0x80, 0xFF, 0x5A, 0x2C)
                : Color.FromArgb(0x4C, 0xDD, 0xF9, 0x4B);
            var halo = new Ellipse
            {
                Width = 52, Height = 52,
                Fill = new SolidColorBrush(haloColor),
                Opacity = 0.6,
            };
            Canvas.SetLeft(halo, cx - 26);
            Canvas.SetTop(halo, cy - 26);
            DotsLayer.Children.Add(halo);

            // 设备 dot avatar 34px
            var dotColor = selected
                ? Color.FromArgb(0xFF, 0xFF, 0x5A, 0x2C)
                : ParseHex(dev.ColorHex);
            var dot = new Border
            {
                Width = 34, Height = 34,
                CornerRadius = new CornerRadius(999),
                Background = new SolidColorBrush(dotColor),
                BorderBrush = new SolidColorBrush(Color.FromArgb(0xFF, 0x0A, 0x0A, 0x0A)),
                BorderThickness = new Thickness(1.4),
                Child = new TextBlock
                {
                    Text = dev.Initials,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center,
                    FontFamily = (FontFamily)Application.Current.Resources["MdDisplayFontFamily"],
                    FontWeight = Windows.UI.Text.FontWeights.SemiBold,
                    FontSize = 11,
                    Foreground = new SolidColorBrush(Color.FromArgb(0xFF, 0x0A, 0x0A, 0x0A)),
                },
            };
            Canvas.SetLeft(dot, cx - 17);
            Canvas.SetTop(dot, cy - 17);
            DotsLayer.Children.Add(dot);

            // label
            var label = new StackPanel
            {
                Orientation = Orientation.Vertical,
                Spacing = -1,
            };
            label.Children.Add(new TextBlock
            {
                Text = dev.Name,
                FontFamily = (FontFamily)Application.Current.Resources["MdBodyFontFamily"],
                FontWeight = Windows.UI.Text.FontWeights.SemiBold,
                FontSize = 11,
                Foreground = (Brush)Application.Current.Resources["MdInkBrush"],
            });
            label.Children.Add(new TextBlock
            {
                Text = $"{dev.Os} · {dev.Rtt} ms",
                FontFamily = (FontFamily)Application.Current.Resources["MdMonoFontFamily"],
                FontSize = 9,
                Opacity = 0.6,
            });
            Canvas.SetLeft(label, cx + 22);
            Canvas.SetTop(label, cy - 8);
            DotsLayer.Children.Add(label);

            // selected：从中心拉一条 flame 虚线
            if (selected)
            {
                var ln = new Line
                {
                    X1 = r, Y1 = r,
                    X2 = cx, Y2 = cy,
                    Stroke = (Brush)Application.Current.Resources["MdFlameBrush"],
                    StrokeThickness = 1.4,
                    StrokeDashArray = new DoubleCollection { 4, 4 },
                    Opacity = 0.7,
                };
                DotsLayer.Children.Insert(0, ln);
            }
        }
    }

    private void StartSweep()
    {
        _sweepStory?.Stop();
        var anim = new DoubleAnimation
        {
            From = 0,
            To = 360,
            Duration = TimeSpan.FromSeconds(4.5),
            RepeatBehavior = RepeatBehavior.Forever,
        };
        Storyboard.SetTarget(anim, SweepRotate);
        Storyboard.SetTargetProperty(anim, "Angle");
        _sweepStory = new Storyboard();
        _sweepStory.Children.Add(anim);
        _sweepStory.Begin();
    }

    private static Color ParseHex(string hex)
    {
        if (string.IsNullOrEmpty(hex)) return Colors.LightGray;
        var s = hex.TrimStart('#');
        if (s.Length == 6) s = "FF" + s;
        if (s.Length != 8) return Colors.LightGray;
        return Color.FromArgb(
            Convert.ToByte(s.Substring(0, 2), 16),
            Convert.ToByte(s.Substring(2, 2), 16),
            Convert.ToByte(s.Substring(4, 2), 16),
            Convert.ToByte(s.Substring(6, 2), 16));
    }
}
