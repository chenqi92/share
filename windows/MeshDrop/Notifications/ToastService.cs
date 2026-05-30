using MeshDrop.Models;
using MeshDrop.Transport;
using Microsoft.Windows.AppNotifications;

namespace MeshDrop.Notifications;

/// <summary>
/// 订阅 ShareEngine.Event，对 incoming 文件 offer / 文本 / 剪贴板弹系统 Toast。
/// 用 Windows App SDK AppNotificationManager —— unpackaged 也需先 Register()。
/// ToastBuilder 只产出 ToastContent（XML），这里负责真正 Show。
/// </summary>
public static class ToastService
{
    private static bool _started;

    public static void Start(ShareEngine engine)
    {
        if (_started) return;
        _started = true;
        try { AppNotificationManager.Default.Register(); }
        catch { /* 注册失败（缺权限 / 环境限制）不致命；后续 Show 静默失败 */ }
        engine.Event += OnEngineEvent;
    }

    private static void OnEngineEvent(EngineEvent ev)
    {
        try
        {
            switch (ev)
            {
                case EngineEvent.OfferPending o:
                    Show(ToastBuilder.BuildIncomingFile(
                        o.Offer.Peer.Name, o.Offer.FileName,
                        ByteFormat.Format(o.Offer.FileSize), offerId: o.Offer.Id.ToString()));
                    break;
                case EngineEvent.HistoryAdded h
                    when h.Item.Direction == TransferDirection.Incoming
                         && h.Item.Kind is HistoryKind.Text t:
                    Show(ToastBuilder.BuildIncomingText(h.Item.Peer.Name, t.Content, h.Item.FormattedTime));
                    break;
                case EngineEvent.ClipboardReceived c:
                    Show(ToastBuilder.BuildIncomingText($"{c.Entry.PeerName} · 剪贴板", c.Entry.Content, ""));
                    break;
            }
        }
        catch { /* Toast 失败不影响主流程 */ }
    }

    private static void Show(CommunityToolkit.WinUI.Notifications.ToastContent content)
    {
        AppNotificationManager.Default.Show(new AppNotification(content.GetContent()));
    }
}
