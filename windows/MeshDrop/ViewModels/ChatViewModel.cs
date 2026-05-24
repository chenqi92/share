using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;

namespace MeshDrop.ViewModels;

public sealed partial class ChatViewModel : ObservableObject
{
    [ObservableProperty]
    private string _peerDisplayName = "李莉 · Lily's MacBook";

    [ObservableProperty]
    private string _peerSubtitle = "macOS 15.3 · 192.168.1.31 · RTT 18 ms";

    public ObservableCollection<MockMessage> Messages { get; } = MockObs.ChatWithLily();

    public string DropOverlayText => "放手即发 · Drop to send · 1 个文件 · 14.2 MB → 李莉";
}
