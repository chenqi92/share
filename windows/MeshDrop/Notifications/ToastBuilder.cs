using CommunityToolkit.WinUI.Notifications;

namespace MeshDrop.Notifications;

/// <summary>
/// 用 CommunityToolkit.WinUI.Notifications 构造 incoming file / text 的 Toast XML。
/// 这里只产出纯 <see cref="ToastContent"/>（无副作用，便于单测 / 预览）；真正弹系统
/// 通知由 <see cref="ToastService"/> 经 Windows App SDK <c>AppNotificationManager</c> 完成。
/// </summary>
public static class ToastBuilder
{
    /// <summary>incoming 文件 offer toast：含 接收 / 拒绝 / 查看 三按钮。</summary>
    public static ToastContent BuildIncomingFile(
        string peer,
        string fileName,
        string sizeText,
        string? note = null,
        string? offerId = null)
    {
        var builder = new ToastContentBuilder()
            .AddText(I18n.T("toast.incomingFileTitleFormat", peer))
            .AddText(fileName)
            .AddAttributionText(I18n.T("toast.attributionFormat", sizeText));

        if (!string.IsNullOrEmpty(note))
        {
            builder.AddText($"“{note}”");
        }

        var oid = offerId ?? "po-1";
        builder.AddButton(new ToastButton(I18n.T("toast.accept"), $"action=accept&offer={oid}")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton(I18n.T("toast.reject"), $"action=reject&offer={oid}")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton(I18n.T("toast.view"), $"action=open&offer={oid}")
            .SetBackgroundActivation());

        return builder.Content;
    }

    /// <summary>
    /// TOFU 待审配对 toast：含 允许并记住 / 允许一次 / 拒绝 三按钮。pairingId 回传给
    /// ShareEngine.RespondToPairing。指纹给用户在 Toast 上直接核对。
    /// </summary>
    public static ToastContent BuildPairingPending(
        string peer,
        string deviceSubtitle,
        string fingerprint,
        string pairingId)
    {
        var builder = new ToastContentBuilder()
            .AddText(I18n.T("toast.pairingTitleFormat", peer))
            .AddText(deviceSubtitle)
            .AddText(I18n.T("toast.fingerprintFormat", fingerprint))
            .AddAttributionText(I18n.T("toast.pairingAttribution"));

        builder.AddButton(new ToastButton(I18n.T("toast.allowRemember"), $"action=pair_trust&pairing={pairingId}")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton(I18n.T("toast.allowOnce"), $"action=pair_once&pairing={pairingId}")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton(I18n.T("toast.reject"), $"action=pair_reject&pairing={pairingId}")
            .SetBackgroundActivation());

        return builder.Content;
    }

    /// <summary>incoming 文本 toast：含 复制 / 回复 / 查看 三按钮。</summary>
    public static ToastContent BuildIncomingText(string peer, string text, string time)
    {
        var builder = new ToastContentBuilder()
            .AddText($"{peer} · {time}")
            .AddText(text);
        builder.AddButton(new ToastButton(I18n.T("toast.copy"), "action=copy")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton(I18n.T("toast.reply"), "action=reply")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton(I18n.T("toast.view"), "action=open")
            .SetBackgroundActivation());
        return builder.Content;
    }
}
