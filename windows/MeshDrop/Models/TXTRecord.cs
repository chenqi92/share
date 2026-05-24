using System.Collections.Generic;
using System.Text;

namespace MeshDrop.Models;

/// <summary>
/// mDNS TXT 记录的编解码。字段见 protocol/discovery.md。
/// </summary>
public static class TXTRecord
{
    public const string ServiceType = "_meshdrop._tcp";

    public static Dictionary<string, string> Encode(
        Identity identity,
        string displayName,
        DeviceOS os,
        string? model,
        ushort port,
        byte protocolVersion = 1)
    {
        var dict = new Dictionary<string, string>
        {
            ["v"] = protocolVersion.ToString(),
            ["id"] = identity.Id,
            ["name"] = Base64Url.Encode(Encoding.UTF8.GetBytes(displayName)),
            ["os"] = os.ToRaw(),
            ["fp"] = identity.Fingerprint,
            ["port"] = port.ToString(),
        };
        if (!string.IsNullOrEmpty(model)) dict["model"] = model;
        return dict;
    }

    public static Device? Decode(IReadOnlyDictionary<string, string> attrs)
    {
        if (!attrs.TryGetValue("v", out var v) || !byte.TryParse(v, out var version)) return null;
        if (!attrs.TryGetValue("id", out var id) || id.Length != 32) return null;
        if (!attrs.TryGetValue("name", out var nameB64)) return null;
        var nameBytes = Base64Url.Decode(nameB64);
        if (nameBytes is null) return null;
        var name = Encoding.UTF8.GetString(nameBytes);
        if (!attrs.TryGetValue("os", out var osStr)) return null;
        var os = DeviceOSExtensions.Parse(osStr);
        if (os is null) return null;
        if (!attrs.TryGetValue("fp", out var fp) || fp.Length != 32) return null;
        if (!attrs.TryGetValue("port", out var portStr) || !ushort.TryParse(portStr, out var port)) return null;
        attrs.TryGetValue("model", out var model);
        return new Device(id, name, os.Value, model, fp, port, version);
    }
}

internal static class Base64Url
{
    public static string Encode(byte[] data)
    {
        var s = System.Convert.ToBase64String(data);
        return s.Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }

    public static byte[]? Decode(string s)
    {
        var normalized = s.Replace('-', '+').Replace('_', '/');
        var pad = (4 - normalized.Length % 4) % 4;
        normalized = normalized.PadRight(normalized.Length + pad, '=');
        try { return System.Convert.FromBase64String(normalized); }
        catch { return null; }
    }
}
