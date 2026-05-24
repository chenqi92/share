using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using MeshDrop.Mock;
using MeshDrop.Models;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

public sealed partial class ChatViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    [ObservableProperty]
    private string _peerId = "";

    [ObservableProperty]
    private string _peerDisplayName = "—";

    [ObservableProperty]
    private string _peerSubtitle = "未选择对端";

    private readonly ProjectedCollection<HistoryItem, MockMessage> _messages;
    public ObservableCollection<MockMessage> Messages => _messages;

    public string DropOverlayText
    {
        get
        {
            var name = string.IsNullOrEmpty(PeerDisplayName) ? "对端" : PeerDisplayName;
            return $"放手即发 · Drop to send · → {name}";
        }
    }

    public ChatViewModel()
    {
        _messages = new ProjectedCollection<HistoryItem, MockMessage>(
            _engine.History,
            h => h.ToMessage(),
            h => string.IsNullOrEmpty(PeerId) || h.Peer.Id == PeerId);
    }

    partial void OnPeerIdChanged(string value)
    {
        _messages.Refresh();
        var peer = _engine.Devices.FirstOrDefault(d => d.Id == value);
        if (peer is not null)
        {
            PeerDisplayName = peer.Name;
            PeerSubtitle = $"{peer.Os} · {peer.Host ?? "—"}";
        }
        OnPropertyChanged(nameof(DropOverlayText));
    }
}
