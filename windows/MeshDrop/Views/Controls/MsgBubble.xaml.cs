using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Controls;
using Windows.ApplicationModel.DataTransfer;
using MeshDrop.Transport;
using System;

namespace MeshDrop.Views.Controls;

public sealed partial class MsgBubble : Microsoft.UI.Xaml.Controls.UserControl
{
    public static readonly DependencyProperty HistoryIdProperty = DependencyProperty.Register(
        nameof(HistoryId), typeof(string), typeof(MsgBubble), new PropertyMetadata(""));
    public string HistoryId { get => (string)GetValue(HistoryIdProperty); set => SetValue(HistoryIdProperty, value); }
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

    public static readonly DependencyProperty LocalPathProperty = DependencyProperty.Register(
        nameof(LocalPath), typeof(string), typeof(MsgBubble), new PropertyMetadata(null));

    public static readonly DependencyProperty StatusTextProperty = DependencyProperty.Register(
        nameof(StatusText), typeof(string), typeof(MsgBubble), new PropertyMetadata(""));

    public string Side { get => (string)GetValue(SideProperty); set => SetValue(SideProperty, value); }
    public string Kind { get => (string)GetValue(KindProperty); set => SetValue(KindProperty, value); }
    public string Text { get => (string)GetValue(TextProperty); set => SetValue(TextProperty, value); }
    public string Time { get => (string)GetValue(TimeProperty); set => SetValue(TimeProperty, value); }
    public bool Delivered { get => (bool)GetValue(DeliveredProperty); set => SetValue(DeliveredProperty, value); }
    public string FileName { get => (string)GetValue(FileNameProperty); set => SetValue(FileNameProperty, value); }
    public string FileSize { get => (string)GetValue(FileSizeProperty); set => SetValue(FileSizeProperty, value); }
    public string FileExt { get => (string)GetValue(FileExtProperty); set => SetValue(FileExtProperty, value); }
    public string? LocalPath { get => (string?)GetValue(LocalPathProperty); set => SetValue(LocalPathProperty, value); }
    public string? StatusText { get => (string?)GetValue(StatusTextProperty); set => SetValue(StatusTextProperty, value); }

    public MsgBubble()
    {
        InitializeComponent();
        Loaded += (_, _) => Apply();
        ActualThemeChanged += (_, _) => Apply();
    }

    private void Apply()
    {
        if (Bubble is null) return;

        var outgoing = Side == "out";
        Root.HorizontalAlignment = outgoing ? HorizontalAlignment.Right : HorizontalAlignment.Left;
        var foreground = (Brush)Application.Current.Resources[outgoing ? "MdBubbleOutFgBrush" : "MdBubbleInFgBrush"];
        FileNameText.Foreground = foreground;
        FileSizeText.Foreground = foreground;
        TransferStatusText.Foreground = foreground;

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
        FileRow.Visibility = Kind != "text" ? Visibility.Visible : Visibility.Collapsed;
        DeliveredText.Visibility = (outgoing && Delivered) ? Visibility.Visible : Visibility.Collapsed;
    }


    private void OnMenuOpening(object sender, object e)
    {
        CopyTextItem.Visibility = Kind == "text" ? Visibility.Visible : Visibility.Collapsed;
        OpenFileItem.Visibility = RevealFileItem.Visibility = SaveFileItem.Visibility =
            Kind != "text" ? Visibility.Visible : Visibility.Collapsed;
        OpenFileItem.IsEnabled = RevealFileItem.IsEnabled = SaveFileItem.IsEnabled = FileActions.Exists(LocalPath);
    }

    private void OnCopyText(object sender, RoutedEventArgs e)
    {
        var data = new DataPackage();
        data.SetText(Text ?? "");
        Clipboard.SetContent(data);
    }

    private async void OnDelete(object sender, RoutedEventArgs e)
    {
        if (!Guid.TryParse(HistoryId, out var id)) return;
        var confirm = new ContentDialog
        {
            XamlRoot = XamlRoot,
            Title = I18n.T("msg.deleteTitle"),
            Content = I18n.T("msg.deleteDetail"),
            PrimaryButtonText = I18n.T("msg.deleteConfirm"),
            CloseButtonText = I18n.T("file.close"),
            DefaultButton = ContentDialogButton.Close,
        };
        if (await confirm.ShowAsync() == ContentDialogResult.Primary) ShareEngine.Shared.RemoveHistoryItem(id);
    }

    private async void OnFileTapped(object sender, Microsoft.UI.Xaml.Input.TappedRoutedEventArgs e)
    {
        e.Handled = true;
        await FileActions.PreviewAsync(LocalPath, XamlRoot);
    }
    private async void OnFileOpen(object sender, RoutedEventArgs e) => await FileActions.PreviewAsync(LocalPath, XamlRoot);
    private void OnFileReveal(object sender, RoutedEventArgs e) => FileActions.Reveal(LocalPath);
    private void OnFileSaveCopy(object sender, RoutedEventArgs e) => FileActions.SaveCopy(LocalPath);
}
