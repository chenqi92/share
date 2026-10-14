using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using Org.BouncyCastle.Security;
using Org.BouncyCastle.Tls;
using Org.BouncyCastle.Tls.Crypto;
using Org.BouncyCastle.Tls.Crypto.Impl.BC;
using Certificate = Org.BouncyCastle.Tls.Certificate;

namespace MeshDrop.Gateway;

// Browser HTTPS uses the existing gateway certificate and pairing-code auth.
// Managed TLS keeps TLS 1.3 available on Windows 10; HTTP/2 is not implemented.
internal sealed class GatewayTls : IDisposable
{
    private readonly TlsServerProtocol _protocol;

    internal GatewayTls(Stream network) => _protocol = new TlsServerProtocol(network);

    internal Stream Authenticate(X509Certificate2 certificate)
    {
        _protocol.Accept(new Server(certificate));
        return new MeshDrop.Transport.DuplexTlsStream(_protocol.Stream);
    }

    public void Dispose() { try { _protocol.Close(); } catch { } }

    private sealed class Server(X509Certificate2 certificate) : DefaultTlsServer(new BcTlsCrypto(new SecureRandom()))
    {
        protected override ProtocolVersion[] GetSupportedVersions() => new[] { ProtocolVersion.TLSv13 };
        protected override int[] GetSupportedCipherSuites() => new[]
        {
            CipherSuite.TLS_AES_256_GCM_SHA384, CipherSuite.TLS_CHACHA20_POLY1305_SHA256,
            CipherSuite.TLS_AES_128_GCM_SHA256
        };
        protected override IList<ProtocolName> GetProtocolNames() => new[] { ProtocolName.AsUtf8Encoding("http/1.1") };
        public override TlsCredentials GetCredentials()
        {
            using var key = certificate.GetRSAPrivateKey() ?? throw new CryptographicException("Missing gateway RSA key.");
            var pkcs8 = key.ExportPkcs8PrivateKey();
            try
            {
                var crypto = (BcTlsCrypto)Crypto;
                return new BcDefaultTlsCredentialedSigner(new TlsCryptoParameters(m_context), crypto,
                    PrivateKeyFactory.CreateKey(pkcs8),
                    new Certificate(Array.Empty<byte>(), new[] { new CertificateEntry(crypto.CreateCertificate(certificate.RawData), null) }),
                    SignatureAndHashAlgorithm.rsa_pss_rsae_sha256);
            }
            finally { CryptographicOperations.ZeroMemory(pkcs8); }
        }
    }
}
