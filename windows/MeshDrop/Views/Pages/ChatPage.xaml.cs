using System;
using System.Linq;
using MeshDrop.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Input;
using Windows.ApplicationModel.DataTransfer;
using Windows.Storage;
using Windows.System;

namespace MeshDrop.Views.Pages;

public sealed partial class ChatPage : Microsoft.UI.Xaml.Controls.UserControl
{
    public ChatViewModel ViewModel { get; }

    public ChatPage()
    {
        ViewModel = new ChatViewModel();
        InitializeComponent();
        PlaintextChip.Text = I18n.T("chat.chipPlaintext");
        ViewModel.Messages.CollectionChanged += (_, _) => QueueScrollToLatest();
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(ChatViewModel.PeerId))
            {
                _followLatest = true;
                QueueScrollToLatest();
            }
        };
        Loaded += (_, _) => QueueScrollToLatest();
    }

    private bool _followLatest = true;
    private bool _scrollQueued;

    private void OnMessagesViewChanged(object sender, Microsoft.UI.Xaml.Controls.ScrollViewerViewChangedEventArgs e)
    {
        if (!_scrollQueued)
            _followLatest = MessagesScroll.ScrollableHeight - MessagesScroll.VerticalOffset < 40;
    }

    private void QueueScrollToLatest()
    {
        if (!_followLatest || _scrollQueued) return;
        _scrollQueued = true;
        DispatcherQueue.TryEnqueue(Microsoft.UI.Dispatching.DispatcherQueuePriority.Low, () =>
        {
            MessagesScroll.UpdateLayout();
            MessagesScroll.ChangeView(null, MessagesScroll.ScrollableHeight, null, true);
            _scrollQueued = false;
        });
    }

    /// <summary>composer 里按 Enter 直接发送（Shift+Enter 不拦，留给将来多行）。</summary>
    private void OnComposerKeyDown(object sender, KeyRoutedEventArgs e)
    {
        if (e.Key != VirtualKey.Enter) return;
        var shift = (Microsoft.UI.Input.InputKeyboardSource
            .GetKeyStateForCurrentThread(VirtualKey.Shift)
            & Windows.UI.Core.CoreVirtualKeyStates.Down) == Windows.UI.Core.CoreVirtualKeyStates.Down;
        if (shift) return;
        e.Handled = true;
        if (ViewModel.SendTextCommand.CanExecute(null))
            ViewModel.SendTextCommand.Execute(null);
    }

    // ─── 拖文件发送 ──────────────────────────────────────────────────────

    private void OnDragOver(object sender, DragEventArgs e)
    {
        if (e.DataView.Contains(StandardDataFormats.StorageItems))
        {
            e.AcceptedOperation = DataPackageOperation.Copy;
            DropOverlay.Visibility = Visibility.Visible;
            if (e.DragUIOverride is { } o)
            {
                o.Caption = I18n.T("chat.dropToSendCaption");
                o.IsCaptionVisible = true;
                o.IsGlyphVisible = true;
            }
        }
        else
        {
            e.AcceptedOperation = DataPackageOperation.None;
        }
    }

    private void OnDragLeave(object sender, DragEventArgs e)
    {
        DropOverlay.Visibility = Visibility.Collapsed;
    }

    private async void OnDrop(object sender, DragEventArgs e)
    {
        DropOverlay.Visibility = Visibility.Collapsed;
        if (!e.DataView.Contains(StandardDataFormats.StorageItems)) return;

        var deferral = e.GetDeferral();
        try
        {
            var items = await e.DataView.GetStorageItemsAsync();
            foreach (var item in items.OfType<StorageFile>())
                ViewModel.SendDroppedFile(item.Path);
        }
        catch { /* 拖拽数据可能不可用，忽略 */ }
        finally { deferral.Complete(); }
    }
}
