using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using MeshDrop.Mock;

namespace MeshDrop.Views.Controls;

public sealed partial class ChipControl : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty TextProperty = DependencyProperty.Register(
        nameof(Text), typeof(string), typeof(ChipControl), new PropertyMetadata(""));

    public static readonly DependencyProperty ToneProperty = DependencyProperty.Register(
        nameof(Tone), typeof(ChipToneName), typeof(ChipControl),
        new PropertyMetadata(ChipToneName.Mute, (d, _) => ((ChipControl)d).Apply()));

    public static readonly DependencyProperty MonoProperty = DependencyProperty.Register(
        nameof(Mono), typeof(bool), typeof(ChipControl),
        new PropertyMetadata(false, (d, _) => ((ChipControl)d).Apply()));

    public string Text { get => (string)GetValue(TextProperty); set => SetValue(TextProperty, value); }
    public ChipToneName Tone { get => (ChipToneName)GetValue(ToneProperty); set => SetValue(ToneProperty, value); }
    public bool Mono { get => (bool)GetValue(MonoProperty); set => SetValue(MonoProperty, value); }

    public ChipControl()
    {
        InitializeComponent();
        Loaded += (_, _) => Apply();
    }

    private void Apply()
    {
        if (Label is null || Pill is null) return;

        switch (Tone)
        {
            case ChipToneName.Mute:
                Pill.Background = (Brush)Application.Current.Resources["MdInk06Brush"];
                Label.Foreground = (Brush)Application.Current.Resources["MdInk60Brush"];
                Pill.BorderThickness = new Thickness(0);
                break;
            case ChipToneName.Lime:
                Pill.Background = (Brush)Application.Current.Resources["MdLimeBrush"];
                Label.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Black);
                Pill.BorderThickness = new Thickness(0);
                break;
            case ChipToneName.Ink:
                Pill.Background = (Brush)Application.Current.Resources["MdInkBrush"];
                Label.Foreground = (Brush)Application.Current.Resources["MdPaperBrush"];
                Pill.BorderThickness = new Thickness(0);
                break;
            case ChipToneName.Outline:
                Pill.Background = new SolidColorBrush(Microsoft.UI.Colors.Transparent);
                Pill.BorderBrush = (Brush)Application.Current.Resources["MdLineBrush"];
                Pill.BorderThickness = new Thickness(1);
                Label.Foreground = (Brush)Application.Current.Resources["MdInk60Brush"];
                break;
            case ChipToneName.Flame:
                Pill.Background = (Brush)Application.Current.Resources["MdFlameBrush"];
                Label.Foreground = new SolidColorBrush(Microsoft.UI.Colors.White);
                Pill.BorderThickness = new Thickness(0);
                break;
            case ChipToneName.Sky:
                Pill.Background = (Brush)Application.Current.Resources["MdSkyBrush"];
                Label.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Black);
                Pill.BorderThickness = new Thickness(0);
                break;
            case ChipToneName.Error:
                Pill.Background = (Brush)Application.Current.Resources["MdErrorBrush"];
                Label.Foreground = new SolidColorBrush(Microsoft.UI.Colors.White);
                Pill.BorderThickness = new Thickness(0);
                break;
        }

        Label.FontFamily = Mono
            ? (FontFamily)Application.Current.Resources["MdMonoFontFamily"]
            : (FontFamily)Application.Current.Resources["MdBodyFontFamily"];

        if (Mono)
        {
            Label.CharacterSpacing = 100;
        }
    }
}
