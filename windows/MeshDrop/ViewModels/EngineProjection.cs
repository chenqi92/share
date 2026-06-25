using System;
using System.Collections.ObjectModel;
using System.Collections.Specialized;
using System.ComponentModel;
using System.Linq;
using MeshDrop.Mock;
using MeshDrop.Models;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

/// <summary>
/// 把 ShareEngine 的真实模型 (Device / HistoryItem) 投影成 view-DTO
/// (MockDevice / MockHistory / MockTransfer / MockMessage / MockTrust)。
///
/// 数据源真实来自 engine — view-DTO 类型只是 XAML / Controls 复用的现成 shape。
/// MockData.cs 静态字段不再被 runtime 引用，仅留给 SwiftUI/WinUI Preview。
/// </summary>
internal static class EngineProjection
{
    // ─── Device → MockDevice ──────────────────────────────────────

    public static MockDevice ToMock(this Device d)
    {
        var kind = d.Os switch
        {
            DeviceOS.Macos => MockKind.Mac,
            DeviceOS.Windows => MockKind.Win,
            DeviceOS.Ios => MockKind.Ios,
            DeviceOS.Android => MockKind.Android,
            DeviceOS.Linux => MockKind.Linux,
            _ => MockKind.Linux,
        };
        var initials = Initials(d.Name);
        var color = ColorFromId(d.Id);
        var (angle, dist) = RadarSlot(d.Id);
        var osLabel = d.Os switch
        {
            DeviceOS.Macos => "macOS",
            DeviceOS.Windows => "Windows",
            DeviceOS.Ios => "iOS",
            DeviceOS.Android => "Android",
            DeviceOS.Linux => "Linux",
            _ => "Linux",
        };
        return new MockDevice(
            Id: d.Id,
            Name: d.Name,
            Who: d.Name,
            Kind: kind,
            Dist: dist,
            Angle: angle,
            ColorHex: color,
            Initials: initials,
            Os: d.Model is null ? osLabel : $"{osLabel} · {d.Model}",
            Rtt: 0,
            Fingerprint: d.HumanFingerprint,
            Ip: d.Host ?? "—",
            Bw: "LAN",
            E2EVerified: true);
    }

    public static string Initials(string name)
    {
        var n = (name ?? "").Trim();
        if (n.Length == 0) return "·";
        var parts = n.Split(new[] { ' ', '·', '-', '_' }, StringSplitOptions.RemoveEmptyEntries);
        if (parts.Length == 0) return n.Substring(0, Math.Min(2, n.Length)).ToUpperInvariant();
        if (parts.Length == 1) return parts[0].Substring(0, Math.Min(2, parts[0].Length)).ToUpperInvariant();
        return (parts[0][0].ToString() + parts[1][0]).ToUpperInvariant();
    }

    public static string ColorFromId(string id)
    {
        string[] palette =
        {
            "#FFB4A1", "#B7E5C8", "#C7B8FF", "#FFD970", "#9AD0FF",
            "#FF9EC4", "#A0E0D6", "#FFC68A", "#C2D6FF", "#EBC0FF",
        };
        var h = 0;
        foreach (var c in id) h = (h * 31 + c) & 0x7FFFFFFF;
        return palette[h % palette.Length];
    }

    private static (int angle, double dist) RadarSlot(string id)
    {
        var h = 0;
        foreach (var c in id) h = (h * 131 + c) & 0x7FFFFFFF;
        var angle = h % 360;
        var dist = 0.32 + (h / 360 % 100) / 100.0 * 0.55;
        return (angle, dist);
    }

    // ─── HistoryItem → MockHistory ────────────────────────────────

    public static MockHistory ToMock(this HistoryItem h)
    {
        var dir = h.Direction == TransferDirection.Outgoing ? "outgoing" : "incoming";
        switch (h.Kind)
        {
            case HistoryKind.Text t:
                return new MockHistory(
                    Id: h.Id.ToString(), Dir: dir, Peer: h.Peer.Name,
                    Time: h.FormattedTime, Kind: MockHistoryKind.Text,
                    Content: t.Content, Status: StatusStr(h.Status), Progress: ProgressPct(h.Status));
            case HistoryKind.File f:
                var ext = System.IO.Path.GetExtension(f.Name).TrimStart('.');
                return new MockHistory(
                    Id: h.Id.ToString(), Dir: dir, Peer: h.Peer.Name,
                    Time: h.FormattedTime, Kind: MockHistoryKind.File,
                    Name: f.Name, Size: ByteFormat.Format(f.Size),
                    Ext: ext, Status: StatusStr(h.Status), Progress: ProgressPct(h.Status));
            default:
                return new MockHistory(
                    Id: h.Id.ToString(), Dir: dir, Peer: h.Peer.Name,
                    Time: h.FormattedTime, Kind: MockHistoryKind.Text);
        }
    }

    public static MockTransfer ToTransfer(this HistoryItem h)
    {
        var name = h.Kind switch
        {
            HistoryKind.File f => f.Name,
            HistoryKind.Text t => Truncate(t.Content, 24),
            _ => "(unknown)",
        };
        var size = h.Kind switch
        {
            HistoryKind.File f => ByteFormat.Format(f.Size),
            HistoryKind.Text t => ByteFormat.Format(System.Text.Encoding.UTF8.GetByteCount(t.Content)),
            _ => "0 B",
        };
        var ext = h.Kind switch
        {
            HistoryKind.File f => System.IO.Path.GetExtension(f.Name).TrimStart('.'),
            _ => "txt",
        };
        var me = MeshDrop.I18n.T("common.me");
        var from = h.Direction == TransferDirection.Outgoing ? me : h.Peer.Name;
        var to = h.Direction == TransferDirection.Outgoing ? h.Peer.Name : me;
        var (state, progress, speed) = h.Status switch
        {
            TransferStatus.Pending => (MockTransferState.Queued, 0, (string?)null),
            TransferStatus.WaitingApproval => (MockTransferState.Queued, 0, (string?)null),
            TransferStatus.Transferring tr => (
                h.Direction == TransferDirection.Outgoing ? MockTransferState.Sending : MockTransferState.Receiving,
                (int)(tr.Fraction * 100), (string?)"—"),
            TransferStatus.Completed => (MockTransferState.Done, 100, (string?)null),
            TransferStatus.Failed => (MockTransferState.Failed, 0, (string?)null),
            TransferStatus.Canceled => (MockTransferState.Failed, 0, (string?)null),
            _ => (MockTransferState.Queued, 0, (string?)null),
        };
        return new MockTransfer(name, size, ext, from, to, progress, state, speed, Id: h.Id.ToString());
    }

    public static MockMessage ToMessage(this HistoryItem h)
    {
        var side = h.Direction == TransferDirection.Outgoing ? "out" : "in";
        var delivered = h.Status is TransferStatus.Completed;
        var time = h.CreatedAt.ToString("HH:mm");
        switch (h.Kind)
        {
            case HistoryKind.Text t:
                return new MockMessage(h.Id.ToString(), side, "text",
                    Text: t.Content, Time: time, Delivered: delivered);
            case HistoryKind.File f:
                return new MockMessage(h.Id.ToString(), side, "file",
                    FileName: f.Name, FileSize: ByteFormat.Format(f.Size),
                    FileExt: System.IO.Path.GetExtension(f.Name).TrimStart('.'),
                    Time: time, Delivered: delivered);
            default:
                return new MockMessage(h.Id.ToString(), side, "text", Time: time, Delivered: delivered);
        }
    }

    // ─── ClipboardEntry → MockClipboard ───────────────────────────

    public static MockClipboard ToMock(this ClipboardEntry e)
    {
        var kind = e.Kind switch
        {
            "link" => MockClipboardKind.Link,
            "code" => MockClipboardKind.Code,
            _ => MockClipboardKind.Text,   // 未知 / "text" 都归 Text
        };
        return new MockClipboard(
            Id: e.Id.ToString(),
            Who: e.PeerName,
            Kind: kind,
            Body: e.Content ?? "",
            Ago: e.ReceivedAt.ToString("HH:mm:ss"));
    }

    public static MockTrust ToMock(this TrustRecord t)
    {
        var date = DateTimeOffset.FromUnixTimeMilliseconds(t.LastSeenMs).LocalDateTime;
        return new MockTrust(
            Who: t.Name, DeviceName: t.Name, Os: "",
            Fingerprint: HumanFingerprint(t.Fingerprint),
            PairedOn: date.ToString("yyyy-MM-dd"),
            LastSeen: date.ToString("HH:mm"),
            RememberAllowed: true);
    }

    private static string HumanFingerprint(string fp)
    {
        var up = (fp ?? "").ToUpperInvariant();
        var sb = new System.Text.StringBuilder();
        for (var i = 0; i < up.Length; i += 4)
        {
            if (i > 0) sb.Append(" · ");
            sb.Append(up.Substring(i, Math.Min(4, up.Length - i)));
        }
        return sb.ToString();
    }

    private static string StatusStr(TransferStatus s) => s switch
    {
        TransferStatus.Pending => "queued",
        TransferStatus.WaitingApproval => "queued",
        TransferStatus.Transferring => "transferring",
        TransferStatus.Completed => "done",
        TransferStatus.Failed => "failed",
        TransferStatus.Canceled => "failed",
        _ => "queued",
    };

    private static int? ProgressPct(TransferStatus s) =>
        s is TransferStatus.Transferring tr ? (int)(tr.Fraction * 100) : null;

    private static string Truncate(string s, int n) =>
        string.IsNullOrEmpty(s) ? "" : (s.Length <= n ? s : s.Substring(0, n) + "…");
}

/// <summary>
/// 把 ShareEngine 的 ObservableCollection&lt;TSource&gt; 实时投影成
/// ObservableCollection&lt;TView&gt;，XAML 直接绑定 view 集合。
/// </summary>
internal sealed class ProjectedCollection<TSource, TView> : ObservableCollection<TView>
    where TSource : class
{
    private readonly Func<TSource, TView> _map;
    private readonly ObservableCollection<TSource> _src;
    private readonly Func<TSource, bool>? _filter;

    public ProjectedCollection(ObservableCollection<TSource> source,
                               Func<TSource, TView> map,
                               Func<TSource, bool>? filter = null)
    {
        _src = source;
        _map = map;
        _filter = filter;
        Rebuild();
        _src.CollectionChanged += OnSrcChanged;
    }

    private void OnSrcChanged(object? sender, NotifyCollectionChangedEventArgs e)
    {
        // 投影做最简：变更时全量重建。Devices/History 量都不大。
        Rebuild();
    }

    public void Refresh() => Rebuild();

    private void Rebuild()
    {
        Clear();
        foreach (var s in _src)
            if (_filter is null || _filter(s))
                Add(_map(s));
    }
}
