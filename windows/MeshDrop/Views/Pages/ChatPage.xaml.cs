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
                o.Caption = "放手即发 · Drop to send";
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
