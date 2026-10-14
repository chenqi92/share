using System;
using System.Collections.Generic;
using System.Formats.Asn1;
using System.Globalization;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using MeshDrop.Models;
using NSec.Cryptography;

namespace MeshDrop.Transport;

// Wire profile shared with Apple TransportSecurity.swift / SystemCertificate.swift.
// A short-lived P-256 TLS key is signed by the existing Ed25519 device identity.
internal static class TransportIdentity
{
    private const string Prefix = "urn:meshdrop:identity:";
    private static readonly byte[] SignatureAlgorithm = Convert.FromHexString("300A06082A8648CE3D040302");
    private static readonly byte[] KeyAlgorithm = Convert.FromHexString("301306072A8648CE3D020106082A8648CE3D030107");

    internal static X509Certificate2 Create(Identity identity, DateTimeOffset? now = null)
    {
        var before = DateTimeOffset.FromUnixTimeSeconds((now ?? DateTimeOffset.UtcNow).ToUnixTimeSeconds() - 300);
        var after = before.AddDays(30);
        using var key = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var signature = SignatureAlgorithmEd.Sign(identity.PrivateKey, Binding(Point(key), before, after));
        var proof = new byte[96];
        identity.PublicKey.Export(KeyBlobFormat.RawPublicKey).CopyTo(proof, 0);
        signature.CopyTo(proof, 32);
        var request = new CertificateRequest("CN=" + identity.Fingerprint, key, HashAlgorithmName.SHA256);
        request.CertificateExtensions.Add(new X509BasicConstraintsExtension(false, false, 0, true));
        request.CertificateExtensions.Add(new X509KeyUsageExtension(X509KeyUsageFlags.DigitalSignature, true));
        request.CertificateExtensions.Add(new X509EnhancedKeyUsageExtension(new OidCollection
        {
            new("1.3.6.1.5.5.7.3.1"), new("1.3.6.1.5.5.7.3.2")
        }, false));
        var san = new AsnWriter(AsnEncodingRules.DER);
        san.PushSequence();
        san.WriteCharacterString(UniversalTagNumber.IA5String, Prefix + Convert.ToBase64String(proof),
            new Asn1Tag(TagClass.ContextSpecific, 6));
        san.PopSequence();
        request.CertificateExtensions.Add(new X509Extension("2.5.29.17", san.Encode(), false));
        return request.CreateSelfSigned(before, after);
    }

    private static NSec.Cryptography.SignatureAlgorithm SignatureAlgorithmEd => NSec.Cryptography.SignatureAlgorithm.Ed25519;

    internal static string Verify(byte[] der, DateTimeOffset? now = null)
    {
        if (der.Length > 16384) throw Invalid();
        var root = new AsnReader(der, AsnEncodingRules.DER);
        var cert = root.ReadSequence();
        root.ThrowIfNotEmpty();
        var tbsBytes = cert.ReadEncodedValue();
        Require(cert.ReadEncodedValue().Span.SequenceEqual(SignatureAlgorithm));
        var signature = cert.ReadBitString(out var padding);
        Require(padding == 0);
        cert.ThrowIfNotEmpty();
        var tbsRoot = new AsnReader(tbsBytes, AsnEncodingRules.DER);
        var tbs = tbsRoot.ReadSequence();
        tbsRoot.ThrowIfNotEmpty();
        Require(tbs.ReadEncodedValue().Span.SequenceEqual(new byte[] { 0xa0, 3, 2, 1, 2 }));
        _ = tbs.ReadInteger();
        Require(tbs.ReadEncodedValue().Span.SequenceEqual(SignatureAlgorithm));
        var issuer = tbs.ReadEncodedValue();
        Require(issuer.Span[0] == 0x30);
        var validity = tbs.ReadSequence();
        var before = ReadTime(validity);
        var after = ReadTime(validity);
        validity.ThrowIfNotEmpty();
        var instant = now ?? DateTimeOffset.UtcNow;
        Require(before <= instant && instant < after);
        Require(tbs.ReadEncodedValue().Span.SequenceEqual(issuer.Span));
        var spki = tbs.ReadSequence();
        Require(spki.ReadEncodedValue().Span.SequenceEqual(KeyAlgorithm));
        var point = spki.ReadBitString(out padding);
        Require(padding == 0 && point.Length == 65 && point[0] == 4);
        spki.ThrowIfNotEmpty();
        using var key = ECDsa.Create(new ECParameters
        {
            Curve = ECCurve.NamedCurves.nistP256,
            Q = new ECPoint { X = point.AsSpan(1, 32).ToArray(), Y = point.AsSpan(33, 32).ToArray() }
        });
        Require(key.VerifyData(tbsBytes.Span, signature, HashAlgorithmName.SHA256, DSASignatureFormat.Rfc3279DerSequence));
        var wrapper = tbs.ReadSequence(new Asn1Tag(TagClass.ContextSpecific, 3, true));
        var extensions = wrapper.ReadSequence();
        wrapper.ThrowIfNotEmpty();
        tbs.ThrowIfNotEmpty();
        var seen = new HashSet<string>();
        byte[]? proof = null;
        while (extensions.HasData)
        {
            var ext = extensions.ReadSequence();
            var oid = ext.ReadObjectIdentifier();
            Require(seen.Add(oid) && seen.Count <= 10);
            var critical = ext.PeekTag().HasSameClassAndValue(Asn1Tag.Boolean) && ext.ReadBoolean();
            var value = ext.ReadOctetString();
            ext.ThrowIfNotEmpty();
            var valueReader = new AsnReader(value, AsnEncodingRules.DER);
            switch (oid)
            {
                case "2.5.29.17":
                    var names = valueReader.ReadSequence();
                    var uri = names.ReadCharacterString(UniversalTagNumber.IA5String, new Asn1Tag(TagClass.ContextSpecific, 6));
                    names.ThrowIfNotEmpty();
                    Require(uri.StartsWith(Prefix, StringComparison.Ordinal));
                    proof = Convert.FromBase64String(uri[Prefix.Length..]);
                    Require(proof.Length == 96);
                    break;
                case "2.5.29.19":
                    valueReader.ReadSequence().ThrowIfNotEmpty();
                    break;
                case "2.5.29.15":
                    Require(value.AsSpan().SequenceEqual(new byte[] { 3, 2, 7, 0x80 }) ||
                            value.AsSpan().SequenceEqual(new byte[] { 3, 2, 5, 0xa0 }));
                    _ = valueReader.ReadEncodedValue();
                    break;
                case "2.5.29.37":
                    var purposes = valueReader.ReadSequence();
                    Require(purposes.HasData);
                    while (purposes.HasData)
                        Require(purposes.ReadObjectIdentifier() is "1.3.6.1.5.5.7.3.1" or "1.3.6.1.5.5.7.3.2");
                    break;
                default:
                    Require(!critical);
                    _ = valueReader.ReadEncodedValue();
                    break;
            }
            valueReader.ThrowIfNotEmpty();
        }
        Require(proof is not null);
        var identityKey = NSec.Cryptography.PublicKey.Import(SignatureAlgorithmEd, proof!.AsSpan(0, 32), KeyBlobFormat.RawPublicKey);
        Require(SignatureAlgorithmEd.Verify(identityKey, Binding(point, before, after), proof.AsSpan(32)));
        return Convert.ToHexString(SHA256.HashData(proof.AsSpan(0, 32)).AsSpan(0, 16)).ToLowerInvariant();
    }

    internal static bool MatchesHello(string? authenticated, string? claimed) =>
        authenticated is not null && claimed is not null &&
        string.Equals(authenticated, claimed, StringComparison.OrdinalIgnoreCase);

    private static byte[] Point(ECDsa key)
    {
        var parameters = key.ExportParameters(false);
        var point = new byte[65];
        point[0] = 4;
        parameters.Q.X!.CopyTo(point, 1);
        parameters.Q.Y!.CopyTo(point, 33);
        return point;
    }

    private static byte[] Binding(byte[] point, DateTimeOffset before, DateTimeOffset after)
    {
        var prefix = Encoding.UTF8.GetBytes("MeshDrop TLS identity v1\0");
        var times = Encoding.UTF8.GetBytes(string.Create(CultureInfo.InvariantCulture,
            $"|{before.ToUnixTimeSeconds()}|{after.ToUnixTimeSeconds()}"));
        var result = new byte[prefix.Length + point.Length + times.Length];
        prefix.CopyTo(result, 0);
        point.CopyTo(result, prefix.Length);
        times.CopyTo(result, prefix.Length + point.Length);
        return result;
    }

    private static DateTimeOffset ReadTime(AsnReader reader)
    {
        var time = reader.PeekTag().HasSameClassAndValue(Asn1Tag.UtcTime)
            ? reader.ReadUtcTime() : reader.ReadGeneralizedTime();
        Require(time.Ticks % TimeSpan.TicksPerSecond == 0);
        return time;
    }
    private static void Require(bool condition) { if (!condition) throw Invalid(); }
    private static CryptographicException Invalid() => new("Invalid MeshDrop transport identity.");
}
