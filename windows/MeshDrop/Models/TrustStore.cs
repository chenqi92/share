using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace MeshDrop.Models;

public sealed record TrustRecord(string Fingerprint, string Name, long LastSeenMs);

/// <summary>
/// 信任的设备指纹库。骨架阶段写到 LocalAppData/MeshDrop/trust.json（DPAPI 加密）。
/// </summary>
public sealed class TrustStore
{
    private readonly string _path;
    private readonly object _lock = new();
    private Dictionary<string, TrustRecord> _records;

    public TrustStore()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MeshDrop");
        Directory.CreateDirectory(dir);
        _path = Path.Combine(dir, "trust.json");
        _records = Load();
    }

    public bool IsTrusted(string fingerprint)
    {
        lock (_lock) return _records.ContainsKey(fingerprint);
    }

    public void Trust(string fingerprint, string name)
    {
        lock (_lock)
        {
            _records[fingerprint] = new TrustRecord(fingerprint, name, DateTimeOffset.UtcNow.ToUnixTimeMilliseconds());
            Persist();
        }
    }

    public void Touch(string fingerprint)
    {
        lock (_lock)
        {
            if (_records.TryGetValue(fingerprint, out var r))
            {
                _records[fingerprint] = r with { LastSeenMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() };
                Persist();
            }
        }
    }

    public void Revoke(string fingerprint)
    {
        lock (_lock)
        {
            if (_records.Remove(fingerprint)) Persist();
        }
    }

    public List<TrustRecord> Snapshot()
    {
        lock (_lock)
            return _records.Values.OrderByDescending(r => r.LastSeenMs).ToList();
    }

    private Dictionary<string, TrustRecord> Load()
    {
        try
        {
            if (!File.Exists(_path)) return new();
            var encrypted = File.ReadAllBytes(_path);
            var raw = Unprotect(encrypted);
            var json = Encoding.UTF8.GetString(raw);
            return JsonSerializer.Deserialize<Dictionary<string, TrustRecord>>(json) ?? new();
        }
        catch { return new(); }
    }

    private void Persist()
    {
        try
        {
            var json = JsonSerializer.Serialize(_records);
            var raw = Encoding.UTF8.GetBytes(json);
            var encrypted = Protect(raw);
            File.WriteAllBytes(_path, encrypted);
        }
        catch { /* silent */ }
    }

    private static byte[] Protect(byte[] raw)
    {
        try
        {
            return ProtectedData.Protect(raw, null, DataProtectionScope.CurrentUser);
        }
        catch (PlatformNotSupportedException)
        {
            return raw;
        }
        catch (CryptographicException)
        {
            return raw;
        }
    }

    private static byte[] Unprotect(byte[] stored)
    {
        try
        {
            return ProtectedData.Unprotect(stored, null, DataProtectionScope.CurrentUser);
        }
        catch (PlatformNotSupportedException)
        {
            return stored;
        }
        catch (CryptographicException)
        {
            return stored;
        }
    }
}
