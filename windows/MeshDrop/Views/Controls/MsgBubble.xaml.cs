using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;

namespace MeshDrop.Views.Controls;

public sealed partial class MsgBubble : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty SideProperty = DependencyProperty.Register(
        nameof(Side), typeof(string), typeof(MsgBubble),
        new PropertyMetadata("in", (d, _) => ((MsgBubble)d).Apply()));

    public static readonly DependencyProperty KindProperty = DependencyProperty.Register(
        nameof(Kind), typeof(string), typeof(MsgBubble),
        new PropertyMetadata("text", (d, _) => ((MsgBubble)d).Apply()));

    public static readonly DependencyProperty TextProperty = DependencyProperty.Register(
        nameof(Text), typeof(string), typeof(MsgBubble), new PropertyMetadata(""));

    public static readonly DependencyProperty TimeProperty = DependencyProperty.Register(
        nameof(Time), typeof(string), typeof(MsgBubble), new PropertyMetadata(""));

    public static readonly DependencyProperty DeliveredProperty = DependencyProperty.Register(
        nameof(Delivered), typeof(bool), typeof(MsgBubble),
        new PropertyMetadata(false, (d, _) => ((MsgBubble)d).Apply()));

    public static readonly DependencyProperty FileNameProperty = DependencyProperty.Register(
        nameof(FileName), typeof(string), typeof(MsgBubble), new PropertyMetadata(""));

    public static readonly DependencyProperty FileSizeProperty = DependencyProperty.Register(
        nameof(FileSize), typeof(string), typeof(MsgBubble), new PropertyMetadata(""));

    public static readonly DependencyProperty FileExtProperty = DependencyProperty.Register(
        nameof(FileExt), typeof(string), typeof(MsgBubble), new PropertyMetadata(""));

    public string Side { get => (string)GetValue(SideProperty); set => SetValue(SideProperty, value); }
    public string Kind { get => (string)GetValue(KindProperty); set => SetValue(KindProperty, value); }
    public string Text { get => (string)GetValue(TextProperty); set => SetValue(TextProperty, value); }
    public string Time { get => (string)GetValue(TimeProperty); set => SetValue(TimeProperty, value); }
    public bool Delivered { get => (bool)GetValue(DeliveredProperty); set => SetValue(DeliveredProperty, value); }
    public string FileName { get => (string)GetValue(FileNameProperty); set => SetValue(FileNameProperty, value); }
    public string FileSize { get => (string)GetValue(FileSizeProperty); set => SetValue(FileSizeProperty, value); }
    public string FileExt { get => (string)GetValue(FileExtProperty); set => SetValue(FileExtProperty, value); }

    public MsgBubble()
    {
        InitializeComponent();
        Loaded += (_, _) => Apply();
    }

    private void Apply()
    {
        if (Bubble is null) return;

        var outgoing = Side == "out";
        Root.HorizontalAlignment = outgoing ? HorizontalAlignment.Right : HorizontalAlignment.Left;

        if (outgoing)
        {
            Bubble.Background = (Brush)Application.Current.Resources["MdBubbleOutBgBrush"];
            TextRun.Foreground = (Brush)Application.Current.Resources["MdBubbleOutFgBrush"];
            TimeText.Foreground = (Brush)Application.Current.Resources["MdBubbleOutFgBrush"];
            TimeText.Opacity = 0.6;
            Bubble.CornerRadius = new CornerRadius(16, 6, 16, 16);
        }
        else
        {
            Bubble.Background = (Brush)Application.Current.Resources["MdBubbleInBgBrush"];
            TextRun.Foreground = (Brush)Application.Current.Resources["MdBubbleInFgBrush"];
            TimeText.Foreground = (Brush)Application.Current.Resources["MdInk60Brush"];
            Bubble.CornerRadius = new CornerRadius(6, 16, 16, 16);
        }

        TextRun.Visibility = Kind == "text" ? Visibility.Visible : Visibility.Collapsed;
        FileRow.Visibility = Kind == "file" ? Visibility.Visible : Visibility.Collapsed;
        DeliveredText.Visibility = (outgoing && Delivered) ? Visibility.Visible : Visibility.Collapsed;
    }
}
