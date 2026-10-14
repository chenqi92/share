using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Windows.Storage;
using Windows.Storage.Pickers;
using Windows.System;

namespace MeshDrop.Views.Controls;

/// <summary>
/// 传输文件的落地操作：打开、在资源管理器中定位、转存一份到指定文件夹。
/// path 来自 HistoryKind.File.LocalPath（发送=源路径 / 接收=保存路径）。
/// 文件不存在（路径为空、已被移动/删除）时静默忽略，绝不抛。
/// </summary>
public static class FileActions
{
    private static bool _previewOpen;

    public static bool Exists(string? path) => !string.IsNullOrEmpty(path) && File.Exists(path);

    public static async Task PreviewAsync(string? path, XamlRoot? root)
    {
        if (!Exists(path) || root is null || _previewOpen) return;
        var extension = Path.GetExtension(path!).ToLowerInvariant();
        if (extension is not (".png" or ".jpg" or ".jpeg" or ".bmp" or ".gif" or ".tif" or ".tiff"))
        {
            Open(path);
            return;
        }

        _previewOpen = true;
        try
        {
            var file = await StorageFile.GetFileFromPathAsync(path);
            using var stream = await file.OpenReadAsync();
            var bitmap = new BitmapImage { DecodePixelWidth = 1600 };
            // Decode before presenting so the dialog's first frame contains the image.
            await bitmap.SetSourceAsync(stream);
            var dialog = new ContentDialog
            {
                Title = file.Name,
                XamlRoot = root,
                Content = new Image
                {
                    Source = bitmap,
                    Stretch = Stretch.Uniform,
                    MaxHeight = Math.Max(160, Math.Min(640, root.Size.Height - 220)),
                },
                CloseButtonText = I18n.T("file.close"),
            };
            await dialog.ShowAsync();
        }
        catch
        {
            Open(path);
        }
        finally { _previewOpen = false; }
    }

    /// <summary>用系统默认程序打开文件。</summary>
    public static async void Open(string? path)
    {
        if (!Exists(path)) return;
        try
        {
            var file = await StorageFile.GetFileFromPathAsync(path);
            await Launcher.LaunchFileAsync(file);
        }
        catch { }
    }

    /// <summary>在资源管理器中打开并选中该文件。</summary>
    public static void Reveal(string? path)
    {
        if (!Exists(path)) return;
        try
        {
            Process.Start(new ProcessStartInfo("explorer.exe", $"/select,\"{path}\"") { UseShellExecute = true });
        }
        catch { }
    }

    /// <summary>转存：选一个文件夹，把文件复制过去（重名自动改名）。</summary>
    public static async void SaveCopy(string? path)
    {
        if (!Exists(path)) return;
        if (App.MainWindow is not { } window) return;
        try
        {
            var src = await StorageFile.GetFileFromPathAsync(path);
            var picker = new FolderPicker { SuggestedStartLocation = PickerLocationId.DocumentsLibrary };
            picker.FileTypeFilter.Add("*"); // FolderPicker 需至少一个过滤项
            var hwnd = WinRT.Interop.WindowNative.GetWindowHandle(window);
            WinRT.Interop.InitializeWithWindow.Initialize(picker, hwnd);

            var folder = await picker.PickSingleFolderAsync();
            if (folder is null) return;
            await src.CopyAsync(folder, src.Name, NameCollisionOption.GenerateUniqueName);
        }
        catch { }
    }
}
