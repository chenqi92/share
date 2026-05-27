using System;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using MeshDrop.Mock;

namespace MeshDrop.Views.Controls;

public sealed partial class TransferRowControl : Microsoft.UI.Xaml.Controls.UserControl
{
    /// <summary>调用方订阅以拿到取消请求；TransfersView 把这个 hook 到 ViewModel.CancelCommand。</summary>
    public event EventHandler? CancelRequested;

    // 显式 'new' 隐藏 FrameworkElement.NameProperty
    public static new readonly DependencyProperty NameProperty = DependencyProperty.Register(
        nameof(Name), typeof(string), typeof(TransferRowControl), new PropertyMetadata(""));

    public static readonly DependencyProperty SizeProperty = DependencyProperty.Register(
        nameof(Size), typeof(string), typeof(TransferRowControl), new PropertyMetadata(""));

    public static readonly DependencyProperty ExtProperty = DependencyProperty.Register(
        nameof(Ext), typeof(string), typeof(TransferRowControl), new PropertyMetadata(""));

    public static readonly DependencyProperty FromToProperty = DependencyProperty.Register(
        nameof(FromTo), typeof(string), typeof(TransferRowControl), new PropertyMetadata(""));

    public static readonly DependencyProperty StateProperty = DependencyProperty.Register(
        nameof(State), typeof(MockTransferState), typeof(TransferRowControl),
        new PropertyMetadata(MockTransferState.Done, (d, _) => ((TransferRowControl)d).Apply()));

    public static readonly DependencyProperty ProgressProperty = DependencyProperty.Register(
        nameof(Progress), typeof(double), typeof(TransferRowControl),
        new PropertyMetadata(0.0, (d, _) => ((TransferRowControl)d).Apply()));

    public static readonly DependencyProperty SpeedProperty = DependencyProperty.Register(
        nameof(Speed), typeof(string), typeof(TransferRowControl),
        new PropertyMetadata(null, (d, _) => ((TransferRowControl)d).Apply()));

    public static readonly DependencyProperty EtaProperty = DependencyProperty.Register(
        nameof(Eta), typeof(string), typeof(TransferRowControl),
        new PropertyMetadata("", (d, _) => ((TransferRowControl)d).Apply()));

    public static readonly DependencyProperty StateBrushProperty = DependencyProperty.Register(
        nameof(StateBrush), typeof(Brush), typeof(TransferRowControl),
        new PropertyMetadata(new SolidColorBrush(Microsoft.UI.Colors.Gray)));

    public static readonly DependencyProperty StateTextProperty = DependencyProperty.Register(
        nameof(StateText), typeof(string), typeof(TransferRowControl), new PropertyMetadata(""));

    public static readonly DependencyProperty EtaTextProperty = DependencyProperty.Register(
        nameof(EtaText), typeof(string), typeof(TransferRowControl), new PropertyMetadata(""));

    public static readonly DependencyProperty ProgressVisibilityProperty = DependencyProperty.Register(
        nameof(ProgressVisibility), typeof(Visibility), typeof(TransferRowControl),
        new PropertyMetadata(Visibility.Collapsed));

    public static readonly DependencyProperty CancelVisibilityProperty = DependencyProperty.Register(
        nameof(CancelVisibility), typeof(Visibility), typeof(TransferRowControl),
        new PropertyMetadata(Visibility.Collapsed));

    public new string Name { get => (string)GetValue(NameProperty); set => SetValue(NameProperty, value); }
    public string Size { get => (string)GetValue(SizeProperty); set => SetValue(SizeProperty, value); }
    public string Ext { get => (string)GetValue(ExtProperty); set => SetValue(ExtProperty, value); }
    public string FromTo { get => (string)GetValue(FromToProperty); set => SetValue(FromToProperty, value); }
    public MockTransferState State { get => (MockTransferState)GetValue(StateProperty); set => SetValue(StateProperty, value); }
    public double Progress { get => (double)GetValue(ProgressProperty); set => SetValue(ProgressProperty, value); }
    public string? Speed { get => (string?)GetValue(SpeedProperty); set => SetValue(SpeedProperty, value); }
    public string Eta { get => (string)GetValue(EtaProperty); set => SetValue(EtaProperty, value); }
    public Brush StateBrush { get => (Brush)GetValue(StateBrushProperty); set => SetValue(StateBrushProperty, value); }
    public string StateText { get => (string)GetValue(StateTextProperty); set => SetValue(StateTextProperty, value); }
    public string EtaText { get => (string)GetValue(EtaTextProperty); set => SetValue(EtaTextProperty, value); }
    public Visibility ProgressVisibility
    {
        get => (Visibility)GetValue(ProgressVisibilityProperty);
        set => SetValue(ProgressVisibilityProperty, value);
    }
    public Visibility CancelVisibility
    {
        get => (Visibility)GetValue(CancelVisibilityProperty);
        set => SetValue(CancelVisibilityProperty, value);
    }

    private void OnCancelClick(object sender, RoutedEventArgs e) => CancelRequested?.Invoke(this, EventArgs.Empty);

    public TransferRowControl()
    {
        InitializeComponent();
        Loaded += (_, _) => Apply();
    }

    private void Apply()
    {
        var res = Application.Current.Resources;
        switch (State)
        {
            case MockTransferState.Sending:
                StateBrush = (Brush)res["MdFlameBrush"];
                StateText = string.IsNullOrEmpty(Speed) ? "↑ 发送中" : $"↑ {Speed}";
                ProgressVisibility = Visibility.Visible;
                CancelVisibility = Visibility.Visible;
                break;
            case MockTransferState.Receiving:
                StateBrush = (Brush)res["MdSkyBrush"];
                StateText = string.IsNullOrEmpty(Speed) ? "↓ 接收中" : $"↓ {Speed}";
                ProgressVisibility = Visibility.Visible;
                CancelVisibility = Visibility.Visible;
                break;
            case MockTransferState.Done:
                StateBrush = (Brush)res["MdLimeDeepBrush"];
                StateText = "✓ 已完成";
                ProgressVisibility = Visibility.Collapsed;
                CancelVisibility = Visibility.Collapsed;
                break;
            case MockTransferState.Failed:
                StateBrush = (Brush)res["MdErrorBrush"];
                StateText = "× 失败";
                ProgressVisibility = Visibility.Collapsed;
                CancelVisibility = Visibility.Collapsed;
                break;
            case MockTransferState.Queued:
            default:
                StateBrush = (Brush)res["MdInk45Brush"];
                StateText = "· 排队";
                ProgressVisibility = Visibility.Collapsed;
                CancelVisibility = Visibility.Collapsed;
                break;
        }

        EtaText = string.IsNullOrEmpty(Eta) ? "" : $"ETA {Eta}";
    }
}
