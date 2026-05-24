using System;
using System.Linq;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace MeshDrop.Gateway;

/// <summary>
/// 自签证书管理：首次启动生成 CN=meshdrop.local 的 X509 证书（含私钥），
/// 存到当前用户的 CurrentUser/My 证书 store；后续启动从 store 读出。
/// </summary>
internal static class GatewayCert
{
    public const string SubjectCommonName = "meshdrop.local";
    public const string FriendlyName = "MeshDrop Local Gateway";

    public static X509Certificate2 LoadOrCreate()
    {
        var store = new X509Store(StoreName.My, StoreLocation.CurrentUser);
        store.Open(OpenFlags.ReadWrite);
        try
        {
            var existing = store.Certificates
                .Find(X509FindType.FindBySubjectName, SubjectCommonName, validOnly: false)
                .Cast<X509Certificate2>()
                .Where(c => c.HasPrivateKey
                            && string.Equals(c.FriendlyName, FriendlyName, StringComparison.Ordinal)
                            && c.NotAfter > DateTime.UtcNow.AddDays(30))
                .OrderByDescending(c => c.NotBefore)
                .FirstOrDefault();
            if (existing is not null) return existing;

            var cert = CreateSelfSigned();
            // 把含私钥的 PFX 重新导入到 store，确保 LocalMachine/CurrentUser 都能拿到密钥
            var pfxBytes = cert.Export(X509ContentType.Pfx);
            var stored = new X509Certificate2(
                pfxBytes,
                password: (string?)null,
                X509KeyStorageFlags.PersistKeySet | X509KeyStorageFlags.Exportable);
            stored.FriendlyName = FriendlyName;
            store.Add(stored);
            return stored;
        }
        finally
        {
            store.Close();
        }
    }

    private static X509Certificate2 CreateSelfSigned()
    {
        using var rsa = RSA.Create(2048);
        var req = new CertificateRequest(
            $"CN={SubjectCommonName}, O=MeshDrop, OU=Local",
            rsa, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);

        req.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, true));
        req.CertificateExtensions.Add(new X509KeyUsageExtension(
            X509KeyUsageFlags.DigitalSignature | X509KeyUsageFlags.KeyEncipherment, true));
        req.CertificateExtensions.Add(new X509EnhancedKeyUsageExtension(
            new OidCollection { new("1.3.6.1.5.5.7.3.1") }, false)); // serverAuth
        var san = new SubjectAlternativeNameBuilder();
        san.AddDnsName(SubjectCommonName);
        san.AddDnsName("localhost");
        san.AddIpAddress(System.Net.IPAddress.Loopback);
        req.CertificateExtensions.Add(san.Build());

        var notBefore = DateTimeOffset.UtcNow.AddDays(-1);
        var notAfter = DateTimeOffset.UtcNow.AddYears(2);
        return req.CreateSelfSigned(notBefore, notAfter);
    }
}
