using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace MeshDrop.Transport;

/// <summary>
/// 接收侧中断传输进度。Key 使用 (peer_fingerprint, sha256)，不依赖 transfer_id，
/// 这样发送端重发同一文件时即使换了 transfer_id，也能续写半成品。
/// </summary>
internal sealed record ResumeRecord(
    [property: JsonPropertyName("peer_fingerprint")] string PeerFingerprint,
    [property: JsonPropertyName("transfer_id")] Guid TransferId,
    [property: JsonPropertyName("file_name")] string FileName,
    [property: JsonPropertyName("file_size")] long FileSize,
    [property: JsonPropertyName("sha256")] string Sha256,
    [property: JsonPropertyName("saved_path")] string SavedPath,
    [property: JsonPropertyName("bytes_done")] long BytesDone,
    [property: JsonPropertyName("updated_at")] DateTimeOffset UpdatedAt)
{
    [JsonIgnore]
    public string Key => MakeKey(PeerFingerprint, Sha256);

    public static string MakeKey(string peerFingerprint, string sha256) =>
        $"{peerFingerprint}:{sha256}";
}

/// <summary>
/// 明文 JSON 的本地断点续传索引。完成、校验失败或用户取消时调用方清理；
/// 连接异常关闭时保留，等待下一次 FILE_OFFER 命中。
/// </summary>
internal sealed class ResumeStore
{
    private static readonly JsonSerializerOptions s_options = new()
    {
        WriteIndented = true,
    };

    private readonly object _gate = new();
    private readonly string _path;
    private Dictionary<string, ResumeRecord> _records;

    public ResumeStore(string? path = null)
    {
        _path = path ?? DefaultPath();
        _records = Load(_path);
    }

    public ResumeRecord? Find(string peerFingerprint, string sha256)
    {
        lock (_gate)
        {
            return _records.TryGetValue(ResumeRecord.MakeKey(peerFingerprint, sha256), out var record)
                ? record
                : null;
        }
    }

    public void Upsert(ResumeRecord record)
    {
        lock (_gate)
        {
            _records[record.Key] = record;
            PersistLocked();
        }
    }

    public void Clear(string peerFingerprint, string sha256)
    {
        lock (_gate)
        {
            _records.Remove(ResumeRecord.MakeKey(peerFingerprint, sha256));
            PersistLocked();
        }
    }

    public IReadOnlyList<ResumeRecord> Snapshot()
    {
        lock (_gate) return new List<ResumeRecord>(_records.Values);
    }

    private void PersistLocked()
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            var data = JsonSerializer.SerializeToUtf8Bytes(_records, s_options);
            var tmp = _path + ".tmp";
            File.WriteAllBytes(tmp, data);
            File.Move(tmp, _path, overwrite: true);
        }
        catch
        {
            // ResumeStore 是 best-effort；失败不应打断正在进行的传输。
        }
    }

    private static Dictionary<string, ResumeRecord> Load(string path)
    {
        try
        {
            if (!File.Exists(path)) return new Dictionary<string, ResumeRecord>(StringComparer.Ordinal);
            return JsonSerializer.Deserialize<Dictionary<string, ResumeRecord>>(File.ReadAllBytes(path), s_options)
                   ?? new Dictionary<string, ResumeRecord>(StringComparer.Ordinal);
        }
        catch
        {
            return new Dictionary<string, ResumeRecord>(StringComparer.Ordinal);
        }
    }

    private static string DefaultPath() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "MeshDrop",
        "resume.json");
}
