using System;
using System.Collections.ObjectModel;
using System.Linq;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using MeshDrop.Models;
using MeshDrop.Transport;

namespace MeshDrop.ViewModels;

/// <summary>
/// 信任管理页 VM：真实绑定 engine.Trusted（已配对设备）+ engine.PendingPairings
/// （TOFU 待审），并暴露 撤销 / 允许并记住 / 允许一次 / 拒绝 命令。
/// </summary>
public sealed partial class TrustViewModel : ObservableObject
{
    private readonly ShareEngine _engine = ShareEngine.Shared;

    public ObservableCollection<TrustRowVM> Trusted { get; }
    public ObservableCollection<PendingPairingVM> Pending { get; }

    public int Count => Trusted.Count;
    public int PendingCount => Pending.Count;

    /// <summary>标题副文案：真实设备数（不再写死 4 台）。</summary>
    public string Subtitle =>
        $"{Count} 台设备已通过指纹验证 · {Count} VERIFIED。撤销后下次连接需重新双向确认。";

    public string PendingDivider => $"── PENDING · 待审 · {PendingCount} ──";

    /// <summary>无待审项时整段收起（项目约定：VM 直接出 Visibility，不引转换器）。</summary>
    public Microsoft.UI.Xaml.Visibility PendingVisibility =>
        PendingCount > 0 ? Microsoft.UI.Xaml.Visibility.Visible : Microsoft.UI.Xaml.Visibility.Collapsed;

    public TrustViewModel()
    {
        Trusted = new ProjectedCollection<TrustRecord, TrustRowVM>(
            _engine.Trusted, TrustRowVM.From);
        Pending = new ProjectedCollection<PendingPairing, PendingPairingVM>(
            _engine.PendingPairings, PendingPairingVM.From);

        Trusted.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(Count));
            OnPropertyChanged(nameof(Subtitle));
        };
        Pending.CollectionChanged += (_, _) =>
        {
            OnPropertyChanged(nameof(PendingCount));
            OnPropertyChanged(nameof(PendingDivider));
            OnPropertyChanged(nameof(PendingVisibility));
        };
    }

    [RelayCommand]
    private void Revoke(TrustRowVM? row)
    {
        if (row is null) return;
        _engine.RevokeTrust(row.RawFingerprint);
    }

    [RelayCommand]
    private void AcceptAndRemember(PendingPairingVM? row)
    {
        if (row is null) return;
        _engine.RespondToPairing(row.Id, PairingDecision.Trust);
    }

    [RelayCommand]
    private void AllowOnce(PendingPairingVM? row)
    {
        if (row is null) return;
        _engine.RespondToPairing(row.Id, PairingDecision.AllowOnce);
    }

    [RelayCommand]
    private void Reject(PendingPairingVM? row)
    {
        if (row is null) return;
        _engine.RespondToPairing(row.Id, PairingDecision.Reject);
    }
}

/// <summary>已信任设备行投影。保留原始 32 hex 指纹用于撤销。</summary>
// 显式 { get; set; }：WinUI XamlTypeInfo 生成代码会尝试 set 绑定属性，
// positional record 默认 init-only 会触发 CS8852（与 MockData.cs 同处理）。
public sealed record TrustRowVM(
    string Who, string DeviceName, string Os, string Fingerprint,
    string PairedOn, string LastSeen, string RawFingerprint)
{
    public string Who { get; set; } = Who;
    public string DeviceName { get; set; } = DeviceName;
    public string Os { get; set; } = Os;
    public string Fingerprint { get; set; } = Fingerprint;
    public string PairedOn { get; set; } = PairedOn;
    public string LastSeen { get; set; } = LastSeen;
    public string RawFingerprint { get; set; } = RawFingerprint;

    public static TrustRowVM From(TrustRecord t)
    {
        var date = DateTimeOffset.FromUnixTimeMilliseconds(t.LastSeenMs).LocalDateTime;
        return new TrustRowVM(
            Who: t.Name,
            DeviceName: t.Name,
            Os: "",
            Fingerprint: HumanFp(t.Fingerprint),
            PairedOn: date.ToString("yyyy-MM-dd"),
            LastSeen: date.ToString("HH:mm"),
            RawFingerprint: t.Fingerprint);
    }

    private static string HumanFp(string fp)
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
}

/// <summary>TOFU 待审配对行投影。Id 用于回调 RespondToPairing。</summary>
public sealed record PendingPairingVM(
    Guid Id, string Who, string DeviceName, string Fingerprint, string ReceivedAt)
{
    public Guid Id { get; set; } = Id;
    public string Who { get; set; } = Who;
    public string DeviceName { get; set; } = DeviceName;
    public string Fingerprint { get; set; } = Fingerprint;
    public string ReceivedAt { get; set; } = ReceivedAt;

    public static PendingPairingVM From(PendingPairing p) => new(
        Id: p.Id,
        Who: p.Peer.Name,
        DeviceName: $"{p.Peer.Os} · {p.Peer.Host ?? "—"}",
        Fingerprint: p.Peer.HumanFingerprint,
        ReceivedAt: p.ReceivedAt.ToString("HH:mm:ss"));
}
