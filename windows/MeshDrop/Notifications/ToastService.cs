using System;
using MeshDrop.Models;
using MeshDrop.Transport;
using Microsoft.UI.Dispatching;
using Microsoft.Windows.AppNotifications;

namespace MeshDrop.Notifications;

/// <summary>
/// 订阅 ShareEngine.Event，对 incoming 文件 offer / 文本 / 剪贴板弹系统 Toast。
/// 用 Windows App SDK AppNotificationManager —— unpackaged 也需先 Register()。
/// ToastBuilder 只产出 ToastContent（XML），这里负责真正 Show 及处理按钮回调。
/// </summary>
public static class ToastService
{
    private static bool _started;
    private static ShareEngine? _engine;

    public static void Start(ShareEngine engine)
    {
        if (_started) return;
        _started = true;
        _engine = engine;

        try
        {
            var mgr = AppNotificationManager.Default;
            // NotificationInvoked 必须在 Register() 之前订阅，否则点 Toast 按钮会冷启动新进程
            // 而不是路由进当前运行的实例（见 Windows App SDK 文档）。
            mgr.NotificationInvoked += OnNotificationInvoked;
            mgr.Register();
        }
        catch { /* 注册失败（缺权限 / 环境限制）不致命；后续 Show 静默失败 */ }

        engine.Event += OnEngineEvent;
    }

    /// <summary>应用退出时调用，释放 COM server 注册。</summary>
    public static void Stop()
    {
        if (!_started) return;
        try { AppNotificationManager.Default.Unregister(); }
        catch { }
        _started = false;
    }

    private static void OnEngineEvent(EngineEvent ev)
    {
        try
        {
            switch (ev)
            {
                case EngineEvent.PairingPending p:
                    Show(ToastBuilder.BuildPairingPending(
                        p.Pairing.Peer.Name,
                        $"{p.Pairing.Peer.Os} · {p.Pairing.Peer.Host ?? "—"}",
                        p.Pairing.Peer.HumanFingerprint,
                        p.Pairing.Id.ToString()));
                    break;
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
                    Show(ToastBuilder.BuildIncomingText(I18n.T("toast.clipboardPeerFormat", c.Entry.PeerName), c.Entry.Content, ""));
                    break;
            }
        }
        catch { /* Toast 失败不影响主流程 */ }
    }

    /// <summary>
    /// 用户点 Toast 按钮（接收 / 拒绝 / 查看）时回调。args.Arguments 已把
    /// "action=accept&amp;offer={guid}" 解析成 dict。本回调在后台线程触发，
    /// 而 engine 的 RespondToFileOffer 会改 ObservableCollection，所以必须切回 UI 线程。
    /// </summary>
    private static void OnNotificationInvoked(AppNotificationManager sender, AppNotificationActivatedEventArgs args)
    {
        try
        {
            var a = args.Arguments;
            if (a is null || !a.TryGetValue("action", out var action)) return;

            switch (action)
            {
                case "accept" when a.TryGetValue("offer", out var aid) && Guid.TryParse(aid, out var acceptId):
                    RunOnUi(() => _engine?.RespondToFileOffer(acceptId, true));
                    break;
                case "reject" when a.TryGetValue("offer", out var rid) && Guid.TryParse(rid, out var rejectId):
                    RunOnUi(() => _engine?.RespondToFileOffer(rejectId, false));
                    break;
                case "pair_trust" when a.TryGetValue("pairing", out var ptid) && Guid.TryParse(ptid, out var pTrustId):
                    RunOnUi(() => _engine?.RespondToPairing(pTrustId, PairingDecision.Trust));
                    break;
                case "pair_once" when a.TryGetValue("pairing", out var poid) && Guid.TryParse(poid, out var pOnceId):
                    RunOnUi(() => _engine?.RespondToPairing(pOnceId, PairingDecision.AllowOnce));
                    break;
                case "pair_reject" when a.TryGetValue("pairing", out var prid) && Guid.TryParse(prid, out var pRejectId):
                    RunOnUi(() => _engine?.RespondToPairing(pRejectId, PairingDecision.Reject));
                    break;
                case "open":
                case "copy":
                case "reply":
                    // 把主窗口带到前台（其余操作目前由应用内 UI 承接）。
                    RunOnUi(BringMainWindowToFront);
                    break;
            }
        }
        catch { /* 回调异常不影响通知系统 */ }
    }

    private static void RunOnUi(Action act)
    {
        var dq = App.MainWindow?.DispatcherQueue;
        if (dq is null) { try { act(); } catch { } return; }
        dq.TryEnqueue(DispatcherQueuePriority.Normal, () => { try { act(); } catch { } });
    }

    private static void BringMainWindowToFront()
    {
        if (App.MainWindow is { } w) w.Activate();
    }

    private static void Show(CommunityToolkit.WinUI.Notifications.ToastContent content)
    {
        // ToastContent.GetContent() 产出 toast XML 字符串；AppNotification 接受该 payload。
        AppNotificationManager.Default.Show(new AppNotification(content.GetContent()));
    }
}
