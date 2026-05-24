using System;
using System.IO;
using MeshDrop.Models;
using MeshDrop.Transport;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Windows.Storage.Pickers;
using WinRT.Interop;

namespace MeshDrop.Views;

/// <summary>
/// 发送对话框（文本 + 文件 segment）。纯 code-behind 构造避免单独 XAML。
/// </summary>
public sealed class SendDialog : ContentDialog
{
    private readonly Device _device;
    private readonly Window _window;
    private readonly ShareEngine _engine = ShareEngine.Shared;

    private readonly SelectorBar _modeBar = new();
    private readonly TextBox _textBox = new() { AcceptsReturn = true, TextWrapping = TextWrapping.Wrap, Height = 160 };
    private readonly Button _filePickButton = new() { Content = "选择文件…" };
    private readonly TextBlock _fileLabel = new() { Text = "未选择文件", Foreground = new SolidColorBrush(Microsoft.UI.Colors.Gray) };
    private readonly StackPanel _textPanel;
    private readonly StackPanel _filePanel;

    private string? _selectedPath;

    public SendDialog(Window window, Device device)
    {
        _window = window;
        _device = device;
        XamlRoot = window.Content.XamlRoot;
        Title = $"发送到 {device.Name}";
        PrimaryButtonText = "发送";
        CloseButtonText = "取消";
        DefaultButton = ContentDialogButton.Primary;
        IsPrimaryButtonEnabled = false;

        // segment
        _modeBar.Items.Add(new SelectorBarItem { Text = "文本", Tag = "text" });
        _modeBar.Items.Add(new SelectorBarItem { Text = "文件", Tag = "file" });
        _modeBar.SelectedItem = _modeBar.Items[0];
        _modeBar.SelectionChanged += (_, __) => UpdateMode();

        _textBox.TextChanged += (_, __) => UpdateCanSend();
        _filePickButton.Click += async (_, __) => await PickFileAsync();

        _textPanel = new StackPanel { Spacing = 8 };
        _textPanel.Children.Add(_textBox);

        _filePanel = new StackPanel { Spacing = 8, Visibility = Visibility.Collapsed };
        _filePanel.Children.Add(_filePickButton);
        _filePanel.Children.Add(_fileLabel);

        var root = new StackPanel { Spacing = 12, Width = 400 };
        root.Children.Add(_modeBar);
        root.Children.Add(_textPanel);
        root.Children.Add(_filePanel);
        Content = root;

        PrimaryButtonClick += OnPrimary;
    }

    private void UpdateMode()
    {
        var isFile = (_modeBar.SelectedItem?.Tag as string) == "file";
        _textPanel.Visibility = isFile ? Visibility.Collapsed : Visibility.Visible;
        _filePanel.Visibility = isFile ? Visibility.Visible : Visibility.Collapsed;
        UpdateCanSend();
    }

    private void UpdateCanSend()
    {
        var isFile = (_modeBar.SelectedItem?.Tag as string) == "file";
        IsPrimaryButtonEnabled = isFile
            ? !string.IsNullOrEmpty(_selectedPath)
            : !string.IsNullOrWhiteSpace(_textBox.Text);
    }

    private async System.Threading.Tasks.Task PickFileAsync()
    {
        var picker = new FileOpenPicker();
        InitializeWithWindow.Initialize(picker, WindowNative.GetWindowHandle(_window));
        picker.FileTypeFilter.Add("*");
        var file = await picker.PickSingleFileAsync();
        if (file is not null)
        {
            _selectedPath = file.Path;
            var info = new FileInfo(file.Path);
            _fileLabel.Text = $"{info.Name} ({ByteFormat.Format(info.Length)})";
            _fileLabel.Foreground = new SolidColorBrush(Microsoft.UI.Colors.Black);
            UpdateCanSend();
        }
    }

    private void OnPrimary(ContentDialog sender, ContentDialogButtonClickEventArgs args)
    {
        var isFile = (_modeBar.SelectedItem?.Tag as string) == "file";
        if (isFile && _selectedPath is not null)
            _engine.SendFile(_device, _selectedPath);
        else if (!isFile)
            _engine.SendText(_device, _textBox.Text);
    }
}
