using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using MeshDrop.Models;
using Org.BouncyCastle.Security;
using Org.BouncyCastle.Tls;
using Org.BouncyCastle.Tls.Crypto;
using Org.BouncyCastle.Tls.Crypto.Impl.BC;
using Certificate = Org.BouncyCastle.Tls.Certificate;
using CertificateRequest = Org.BouncyCastle.Tls.CertificateRequest;

namespace MeshDrop.Transport;

// Bouncy Castle supplies TLS 1.3 on Windows 10 as well as Windows 11.
// No SChannel dependency, protocol downgrade, CA installation or trust bypass.
internal sealed class SecureTransport : IDisposable
{
    private static readonly ProtocolName Alpn = ProtocolName.AsUtf8Encoding("meshdrop/1");
    private static readonly SignatureAndHashAlgorithm SignAlgorithm =
        SignatureAndHashAlgorithm.GetInstance(Org.BouncyCastle.Tls.HashAlgorithm.sha256, SignatureAlgorithm.ecdsa);
    private static readonly int[] Suites = { CipherSuite.TLS_AES_256_GCM_SHA384, CipherSuite.TLS_CHACHA20_POLY1305_SHA256 };
    private readonly BcTlsCrypto _crypto = new(new SecureRandom());
    private readonly X509Certificate2 _certificate;
    private readonly string? _expectedFingerprint;
    private TlsProtocol? _protocol;
    internal string? AuthenticatedFingerprint { get; private set; }

    internal SecureTransport(Identity identity, string? expectedFingerprint)
    {
        _certificate = TransportIdentity.Create(identity);
        _expectedFingerprint = expectedFingerprint;
    }

    // Runs on Connection's worker. Closing the underlying socket cancels blocked I/O.
    internal Stream Authenticate(Stream network, bool server)
    {
        if (server)
        {
            var protocol = new TlsServerProtocol(network);
            _protocol = protocol;
            protocol.Accept(new Server(this));
        }
        else
        {
            var protocol = new TlsClientProtocol(network);
            _protocol = protocol;
            protocol.Connect(new Client(this));
        }
        if (AuthenticatedFingerprint is null) throw new IOException("TLS peer identity is missing.");
        return new DuplexTlsStream(_protocol.Stream);
    }

    private void Verify(Certificate chain)
    {
        try
        {
            if (chain.Length != 1) throw new CryptographicException("Expected a single device certificate.");
            var fingerprint = TransportIdentity.Verify(chain.GetCertificateAt(0).GetEncoded());
            if (_expectedFingerprint is not null && !TransportIdentity.MatchesHello(fingerprint, _expectedFingerprint))
                throw new CryptographicException("Device fingerprint does not match discovery.");
            AuthenticatedFingerprint = fingerprint;
        }
        catch (Exception ex) { throw new TlsFatalAlert(AlertDescription.bad_certificate, ex); }
    }

    private TlsCredentials Credentials(TlsContext context)
    {
        using var key = _certificate.GetECDsaPrivateKey()!;
        var pkcs8 = key.ExportPkcs8PrivateKey();
        try
        {
            return new BcDefaultTlsCredentialedSigner(new TlsCryptoParameters(context), _crypto,
                PrivateKeyFactory.CreateKey(pkcs8),
                new Certificate(Array.Empty<byte>(), new[] { new CertificateEntry(_crypto.CreateCertificate(_certificate.RawData), null) }),
                SignAlgorithm);
        }
        finally { CryptographicOperations.ZeroMemory(pkcs8); }
    }

    private void Completed(TlsContext context)
    {
        if (!Alpn.Equals(context.SecurityParameters.ApplicationProtocol) || AuthenticatedFingerprint is null)
            throw new TlsFatalAlert(AlertDescription.handshake_failure);
    }

    public void Dispose()
    {
        try { _protocol?.Close(); } catch { }
        _certificate.Dispose();
    }

    private sealed class Client(SecureTransport owner) : DefaultTlsClient(owner._crypto), TlsAuthentication
    {
        protected override ProtocolVersion[] GetSupportedVersions() => new[] { ProtocolVersion.TLSv13 };
        protected override int[] GetSupportedCipherSuites() => Suites;
        protected override IList<ProtocolName> GetProtocolNames() => new[] { Alpn };
        public override TlsAuthentication GetAuthentication() => this;
        public void NotifyServerCertificate(TlsServerCertificate certificate) => owner.Verify(certificate.Certificate);
        public TlsCredentials GetClientCredentials(CertificateRequest request) => owner.Credentials(m_context);
        public override void NotifyHandshakeComplete() { base.NotifyHandshakeComplete(); owner.Completed(m_context); }
    }

    private sealed class Server(SecureTransport owner) : DefaultTlsServer(owner._crypto)
    {
        protected override ProtocolVersion[] GetSupportedVersions() => new[] { ProtocolVersion.TLSv13 };
        protected override int[] GetSupportedCipherSuites() => Suites;
        protected override IList<ProtocolName> GetProtocolNames() => new[] { Alpn };
        public override TlsCredentials GetCredentials() => owner.Credentials(m_context);
        public override CertificateRequest GetCertificateRequest() => new(Array.Empty<byte>(), new[] { SignAlgorithm }, null, null);
        public override void NotifyClientCertificate(Certificate certificate) => owner.Verify(certificate);
        public override void NotifyHandshakeComplete() { base.NotifyHandshakeComplete(); owner.Completed(m_context); }
    }
}
