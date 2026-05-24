using System;
using System.IO;
using System.Text;
using System.Text.Json;

namespace MeshDrop.Gateway;

/// <summary>
/// 6 字符 pairing code，24h 有效。存 LocalAppData/MeshDrop/gateway-pairing.json。
/// </summary>
internal sealed class PairingCodeStore
{
    private readonly string _path;
    private CodeRecord _current;

    public PairingCodeStore()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "MeshDrop");
        Directory.CreateDirectory(dir);
        _path = Path.Combine(dir, "gateway-pairing.json");
        _current = Load() ?? Rotate();
        if (IsExpired(_current)) _current = Rotate();
    }

    public string Code => _current.Code;
    public DateTimeOffset ExpiresAt => DateTimeOffset.FromUnixTimeSeconds(_current.ExpiresUnix);

    public bool IsExpired(CodeRecord r) => DateTimeOffset.UtcNow.ToUnixTimeSeconds() >= r.ExpiresUnix;

    public CodeRecord Rotate()
    {
        var code = GenerateCode();
        var rec = new CodeRecord(
            code,
            DateTimeOffset.UtcNow.AddHours(24).ToUnixTimeSeconds());
        _current = rec;
        Persist();
        return rec;
    }

    public bool Verify(string input)
    {
        if (string.IsNullOrEmpty(input)) return false;
        if (IsExpired(_current)) _current = Rotate();
        return string.Equals(input.Trim().ToUpperInvariant(), _current.Code, StringComparison.Ordinal);
    }

    private CodeRecord? Load()
    {
        try
        {
            if (!File.Exists(_path)) return null;
            var json = File.ReadAllText(_path);
            return JsonSerializer.Deserialize<CodeRecord>(json);
        }
        catch { return null; }
    }

    private void Persist()
    {
        try { File.WriteAllText(_path, JsonSerializer.Serialize(_current)); } catch { }
    }

    private static string GenerateCode()
    {
        // 排除易混淆字符 (0/O, 1/I/L)
        const string alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
        Span<byte> buf = stackalloc byte[6];
        System.Security.Cryptography.RandomNumberGenerator.Fill(buf);
        var sb = new StringBuilder(6);
        foreach (var b in buf) sb.Append(alphabet[b % alphabet.Length]);
        return sb.ToString();
    }

    public sealed record CodeRecord(string Code, long ExpiresUnix);
}
