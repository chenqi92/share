using System;
using System.IO;
using System.Security.Cryptography;
using NSec.Cryptography;

namespace MeshDrop.Models;

/// <summary>
/// 设备身份。Ed25519 长期密钥 (libsodium via NSec) + UUID。
///
/// 私钥持久化：v0.1 用 DPAPI 加密 + 文件落 LocalAppData。
/// </summary>
public sealed class Identity
{
    public string Id { get; }
    public Key PrivateKey { get; }
    public PublicKey PublicKey { get; }
    public string Fingerprint { get; }

    private Identity(string id, Key privateKey)
    {
        Id = id;
        PrivateKey = privateKey;
        PublicKey = privateKey.PublicKey;
        Fingerprint = ComputeFingerprint(PublicKey);
    }

    public static string ComputeFingerprint(PublicKey publicKey)
    {
        var raw = publicKey.Export(KeyBlobFormat.RawPublicKey);
        var hash = SHA256.HashData(raw);
        var sb = new System.Text.StringBuilder(32);
        for (var i = 0; i < 16; i++) sb.AppendFormat("{0:x2}", hash[i]);
        return sb.ToString();
    }

    public static Identity LoadOrCreate()
    {
        var dir = StoragePath;
        Directory.CreateDirectory(dir);

        var idPath = Path.Combine(dir, "id");
        var keyPath = Path.Combine(dir, "ed25519.bin");

        if (File.Exists(idPath) && File.Exists(keyPath))
        {
            var id = File.ReadAllText(idPath).Trim();
            var encrypted = File.ReadAllBytes(keyPath);
            var raw = ProtectedData.Unprotect(encrypted, null, DataProtectionScope.CurrentUser);
            var pk = Key.Import(SignatureAlgorithm.Ed25519, raw, KeyBlobFormat.RawPrivateKey,
                new KeyCreationParameters { ExportPolicy = KeyExportPolicies.AllowPlaintextExport });
            return new Identity(id, pk);
        }

        return Create(idPath, keyPath);
    }

    public static void Reset()
    {
        try { Directory.Delete(StoragePath, recursive: true); } catch { /* ignore */ }
    }

    private static Identity Create(string idPath, string keyPath)
    {
        var id = Guid.NewGuid().ToString("N");      // 32 hex, 小写
        var pk = Key.Create(SignatureAlgorithm.Ed25519,
            new KeyCreationParameters { ExportPolicy = KeyExportPolicies.AllowPlaintextExport });
        var raw = pk.Export(KeyBlobFormat.RawPrivateKey);
        var encrypted = ProtectedData.Protect(raw, null, DataProtectionScope.CurrentUser);
        File.WriteAllBytes(keyPath, encrypted);
        File.WriteAllText(idPath, id);
        return new Identity(id, pk);
    }

    private static string StoragePath
    {
        get
        {
            var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            return Path.Combine(local, "MeshDrop");
        }
    }
}
