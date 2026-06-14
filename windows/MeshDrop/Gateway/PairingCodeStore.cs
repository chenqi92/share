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
        // 恒定时间比较，避免按字符提前返回泄漏匹配前缀长度（计时侧信道）。
        var a = Encoding.UTF8.GetBytes(input.Trim().ToUpperInvariant());
        var b = Encoding.UTF8.GetBytes(_current.Code);
        return System.Security.Cryptography.CryptographicOperations.FixedTimeEquals(a, b);
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
        const string alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // 30 个字符
        // 拒绝采样消除取模偏差：256 不是 30 的整数倍，直接 b % 30 会让前 16 个字符
        // 出现概率略高。丢弃 >= floor(256/30)*30 = 240 的字节，保证均匀。
        const int limit = 256 - (256 % 30); // = 240
        var sb = new StringBuilder(6);
        Span<byte> one = stackalloc byte[1];
        while (sb.Length < 6)
        {
            System.Security.Cryptography.RandomNumberGenerator.Fill(one);
            if (one[0] >= limit) continue; // 落在偏差区间，重抽
            sb.Append(alphabet[one[0] % alphabet.Length]);
        }
        return sb.ToString();
    }

    public sealed record CodeRecord(string Code, long ExpiresUnix);
}
