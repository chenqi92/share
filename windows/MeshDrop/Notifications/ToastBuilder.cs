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
            .AddText($"{peer} 想发文件给你")
            .AddText(fileName)
            .AddAttributionText($"meshdrop · {sizeText}");

        if (!string.IsNullOrEmpty(note))
        {
            builder.AddText($"“{note}”");
        }

        var oid = offerId ?? "po-1";
        builder.AddButton(new ToastButton("接收", $"action=accept&offer={oid}")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton("拒绝", $"action=reject&offer={oid}")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton("查看", $"action=open&offer={oid}")
            .SetBackgroundActivation());

        return builder.Content;
    }

    /// <summary>incoming 文本 toast：含 复制 / 回复 / 查看 三按钮。</summary>
    public static ToastContent BuildIncomingText(string peer, string text, string time)
    {
        var builder = new ToastContentBuilder()
            .AddText($"{peer} · {time}")
            .AddText(text);
        builder.AddButton(new ToastButton("复制", "action=copy")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton("回复", "action=reply")
            .SetBackgroundActivation());
        builder.AddButton(new ToastButton("查看", "action=open")
            .SetBackgroundActivation());
        return builder.Content;
    }
}
