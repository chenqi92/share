using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MeshDrop.Models;

/// <summary>
/// 历史条目的可序列化快照（与 trust.json / resume.json 同范式）。
///
/// 为什么要 DTO 而不是直接序列化 <see cref="HistoryItem"/>：HistoryItem 内嵌的
/// HistoryKind / TransferStatus 是抽象 record + 多个 sealed 子 record（discriminated
/// union），System.Text.Json 无法直接多态序列化；同时对端 <see cref="Device"/> 字段较多
/// 且历史只需展示用快照（对端可能已离线，端口/host 这些瞬时字段无意义）。这里把对端拍成
/// {fp, name, os} 快照，kind / status 拍成扁平字符串 + 附属字段。
/// </summary>
internal sealed record HistoryRecord(
    [property: JsonPropertyName("id")] Guid Id,
    [property: JsonPropertyName("peer_fp")] string PeerFingerprint,
    [property: JsonPropertyName("peer_name")] string PeerName,
    [property: JsonPropertyName("peer_os")] string PeerOs,
    // "outgoing" | "incoming"
    [property: JsonPropertyName("direction")] string Direction,
    // "text" | "file"
    [property: JsonPropertyName("kind")] string Kind,
    [property: JsonPropertyName("text")] string? Text,
    [property: JsonPropertyName("file_name")] string? FileName,
    [property: JsonPropertyName("file_size")] long FileSize,
    [property: JsonPropertyName("local_path")] string? LocalPath,
    // "pending" | "waiting" | "transferring" | "completed" | "failed" | "canceled"
    [property: JsonPropertyName("status")] string Status,
    [property: JsonPropertyName("fail_reason")] string? FailReason,
    [property: JsonPropertyName("created_at")] DateTimeOffset CreatedAt)
{
    public static HistoryRecord From(HistoryItem h)
    {
        var (kind, text, fileName, fileSize, localPath) = h.Kind switch
        {
            HistoryKind.Text t => ("text", t.Content, (string?)null, 0L, (string?)null),
            HistoryKind.File f => ("file", (string?)null, f.Name, f.Size, f.LocalPath),
            _ => ("text", (string?)null, (string?)null, 0L, (string?)null),
        };
        var (status, failReason) = h.Status switch
        {
            // 进行中态落盘时降级为「失败/中断」，避免下次启动把一个永远卡在
            // transferring 的幽灵条目读回来（连接早已断、不会再有进度更新）。
            TransferStatus.Pending => ("failed", "interrupted"),
            TransferStatus.WaitingApproval => ("failed", "interrupted"),
            TransferStatus.Transferring => ("failed", "interrupted"),
            TransferStatus.Completed => ("completed", (string?)null),
            TransferStatus.Failed f => ("failed", f.Reason),
            TransferStatus.Canceled => ("canceled", (string?)null),
            _ => ("failed", "interrupted"),
        };
        return new HistoryRecord(
            h.Id,
            h.Peer.Fingerprint,
            h.Peer.Name,
            h.Peer.Os.ToRaw(),
            h.Direction == TransferDirection.Outgoing ? "outgoing" : "incoming",
            kind, text, fileName, fileSize, localPath,
            status, failReason, new DateTimeOffset(h.CreatedAt));
    }

    public HistoryItem ToItem()
    {
        var os = DeviceOSExtensions.Parse(PeerOs) ?? DeviceOS.Linux;
        // 历史展示用快照：端口/host 用占位值，不参与任何连接。
        var peer = new Device(PeerFingerprint, PeerName, os, null, PeerFingerprint, 0, 1, null);
        var direction = Direction == "outgoing" ? TransferDirection.Outgoing : TransferDirection.Incoming;
        HistoryKind kind = Kind == "file"
            ? new HistoryKind.File(FileName ?? "(unknown)", FileSize, LocalPath)
            : new HistoryKind.Text(Text ?? "");
        TransferStatus status = Status switch
        {
            "completed" => new TransferStatus.Completed(),
            "canceled" => new TransferStatus.Canceled(),
            "failed" => new TransferStatus.Failed(FailReason ?? "failed"),
            _ => new TransferStatus.Failed(FailReason ?? "interrupted"),
        };
        return new HistoryItem(Id, peer, direction, kind, status, CreatedAt.LocalDateTime);
    }
}

/// <summary>
/// 明文 JSON 的本地历史持久化（与 TrustStore / ResumeStore 同目录、同范式）。
/// 落 LocalAppData/MeshDrop/history.json。启动时 load 进内存；每次新增/状态更新后
/// 整表覆盖写（Save 接收当前完整列表快照）。上限 500 条，超出截最旧（按 createdAt）。
/// </summary>
internal sealed class HistoryStore
{
    public const int MaxItems = 500;

    private static readonly JsonSerializerOptions s_options = new()
    {
        WriteIndented = true,
    };

    private readonly object _gate = new();
    private readonly string _path;

    public HistoryStore(string? path = null)
    {
        _path = path ?? DefaultPath();
    }

    /// <summary>启动时读回，按 createdAt 降序（最新在前，与内存 History.Insert(0, …) 一致）。</summary>
    public List<HistoryItem> Load()
    {
        lock (_gate)
        {
            try
            {
                if (!File.Exists(_path)) return new List<HistoryItem>();
                var records = JsonSerializer.Deserialize<List<HistoryRecord>>(File.ReadAllBytes(_path), s_options)
                              ?? new List<HistoryRecord>();
                return records
                    .OrderByDescending(r => r.CreatedAt)
                    .Take(MaxItems)
                    .Select(r => r.ToItem())
                    .ToList();
            }
            catch
            {
                return new List<HistoryItem>();
            }
        }
    }

    /// <summary>
    /// 整表覆盖写当前内存历史。调用方传当前完整快照（最新在前），这里截断到上限后落盘。
    /// best-effort：失败不抛，避免打断收发主流程。
    /// </summary>
    public void Save(IReadOnlyList<HistoryItem> items)
    {
        lock (_gate)
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
                var records = items
                    .Take(MaxItems)
                    .Select(HistoryRecord.From)
                    .ToList();
                var data = JsonSerializer.SerializeToUtf8Bytes(records, s_options);
                var tmp = _path + ".tmp";
                File.WriteAllBytes(tmp, data);
                File.Move(tmp, _path, overwrite: true);
            }
            catch
            {
                // 历史持久化是 best-effort；写失败不应影响传输。
            }
        }
    }

    private static string DefaultPath() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MeshDrop",
        "history.json");
}
