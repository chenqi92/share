using System;
using Microsoft.Windows.AppNotifications;
using Microsoft.Windows.AppNotifications.Builder;

namespace MeshDrop.Notifications;

public static class ToastBuilder
{
    public static AppNotification BuildIncomingFile(string peer, string fileName, string sizeText, Guid decisionId)
    {
        var id = decisionId.ToString();
        return new AppNotificationBuilder()
            .AddArgument("action", "open")
            .AddText(I18n.T("toast.incomingFileTitleFormat", peer))
            .AddText(fileName)
            .SetAttributionText(I18n.T("toast.attributionFormat", sizeText))
            .AddButton(new AppNotificationButton(I18n.T("toast.accept"))
                .AddArgument("action", "accept").AddArgument("offer", id))
            .AddButton(new AppNotificationButton(I18n.T("toast.reject"))
                .AddArgument("action", "reject").AddArgument("offer", id))
            .BuildNotification();
    }

    public static AppNotification BuildPairingPending(string peer, string deviceSubtitle, string fingerprint, Guid pairingId)
    {
        var id = pairingId.ToString();
        return new AppNotificationBuilder()
            .AddArgument("action", "open")
            .AddText(I18n.T("toast.pairingTitleFormat", peer))
            .AddText(deviceSubtitle)
            .AddText(I18n.T("toast.fingerprintFormat", fingerprint))
            .AddButton(new AppNotificationButton(I18n.T("toast.allowRemember"))
                .AddArgument("action", "pair_trust").AddArgument("pairing", id))
            .AddButton(new AppNotificationButton(I18n.T("toast.allowOnce"))
                .AddArgument("action", "pair_once").AddArgument("pairing", id))
            .AddButton(new AppNotificationButton(I18n.T("toast.reject"))
                .AddArgument("action", "pair_reject").AddArgument("pairing", id))
            .BuildNotification();
    }

    public static AppNotification BuildIncomingText(string peer, string text, string time) =>
        new AppNotificationBuilder()
            .AddArgument("action", "open")
            .AddText($"{peer} · {time}")
            .AddText(text)
            .AddButton(new AppNotificationButton(I18n.T("toast.view")).AddArgument("action", "open"))
            .BuildNotification();
}
