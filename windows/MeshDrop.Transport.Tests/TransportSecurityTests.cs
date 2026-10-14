using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using MeshDrop.Models;
using MeshDrop.Transport;
using MeshDrop.Gateway;
using NSec.Cryptography;
using Xunit;

namespace MeshDrop.Transport.Tests;

public sealed class TransportSecurityTests
{
    private static Identity NewIdentity() => new(Guid.NewGuid().ToString("N"), Key.Create(SignatureAlgorithm.Ed25519));

    [Fact]
    public void CertificateBindsExistingIdentityAndValidity()
    {
        var identity = NewIdentity();
        var now = DateTimeOffset.FromUnixTimeSeconds(1790000000);
        using var cert = TransportIdentity.Create(identity, now);
        Assert.Equal(identity.Fingerprint, TransportIdentity.Verify(cert.RawData, now));
        Assert.ThrowsAny<Exception>(() => TransportIdentity.Verify(cert.RawData, now.AddDays(31)));
        Assert.ThrowsAny<Exception>(() => TransportIdentity.Verify(cert.RawData, now.AddSeconds(-301)));
        var damaged = cert.RawData;
        damaged[^8] ^= 1;
        Assert.ThrowsAny<Exception>(() => TransportIdentity.Verify(damaged, now));
        Assert.ThrowsAny<Exception>(() => TransportIdentity.Verify(cert.RawData.Concat(new byte[] { 0 }).ToArray(), now));
        Assert.ThrowsAny<Exception>(() => TransportIdentity.Verify(cert.RawData[..40], now));
        Assert.False(TransportIdentity.MatchesHello(identity.Fingerprint, new string('0', 32)));
        Assert.False(TransportIdentity.MatchesHello(null, null));
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void IdentityProofCannotBeMovedToAnotherKeyOrExtended(bool replaceKey)
    {
        using var cert = TransportIdentity.Create(NewIdentity());
        using var key = replaceKey ? ECDsa.Create(ECCurve.NamedCurves.nistP256) : cert.GetECDsaPrivateKey()!;
        var request = new CertificateRequest(cert.SubjectName, key, HashAlgorithmName.SHA256);
        foreach (var extension in cert.Extensions) request.CertificateExtensions.Add(extension);
        using var forged = request.CreateSelfSigned(cert.NotBefore.ToUniversalTime(), cert.NotAfter.ToUniversalTime().AddDays(replaceKey ? 0 : 1));
        Assert.ThrowsAny<Exception>(() => TransportIdentity.Verify(forged.RawData));
    }

    [Fact]
    public async Task ManagedTLSAuthenticatesBothPeersAndTransfersFramedTextAndFileBytes()
    {
        var serverId = NewIdentity();
        var clientId = NewIdentity();
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var accepting = listener.AcceptTcpClientAsync();
        using var client = Connection.ForOutgoing("127.0.0.1", ((IPEndPoint)listener.LocalEndpoint).Port, clientId, serverId.Fingerprint);
        var gotText = new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously);
        var gotFile = new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously);
        var file = RandomNumberGenerator.GetBytes(200_000);
        client.Start(() => client.SendAsync(0x10, Encoding.UTF8.GetBytes("Hello 苹果 🍎")),
            (type, body) => { if (type == 0x30) gotFile.TrySetResult(body); return Task.CompletedTask; },
            error => { if (error != null) gotFile.TrySetException(error); return Task.CompletedTask; });
        using var incoming = await accepting.WaitAsync(TimeSpan.FromSeconds(10));
        using var server = Connection.ForIncoming(incoming, serverId);
        server.Start(() => Task.CompletedTask, async (type, body) =>
        {
            if (type == 0x10) { gotText.TrySetResult(body); await server.SendAsync(0x30, file); }
        }, error => { if (error != null) gotText.TrySetException(error); return Task.CompletedTask; });
        Assert.Equal("Hello 苹果 🍎", Encoding.UTF8.GetString(await gotText.Task.WaitAsync(TimeSpan.FromSeconds(15))));
        Assert.Equal(file, await gotFile.Task.WaitAsync(TimeSpan.FromSeconds(15)));
        Assert.Equal(serverId.Fingerprint, client.AuthenticatedFingerprint);
        Assert.Equal(clientId.Fingerprint, server.AuthenticatedFingerprint);
    }

    [Fact]
    public async Task ReceiveApprovalCanBeSentWhileConnectionIsWaitingForNextFrame()
    {
        var serverId = NewIdentity();
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var accepting = listener.AcceptTcpClientAsync();
        using var client = Connection.ForOutgoing("127.0.0.1", ((IPEndPoint)listener.LocalEndpoint).Port, NewIdentity(), serverId.Fingerprint);
        var offered = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var received = new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously);
        var photo = RandomNumberGenerator.GetBytes(517_099);
        client.Start(() => client.SendAsync(0x20, new byte[] { 1 }), async (type, _) =>
        {
            if (type == 0x21) await client.SendAsync(0x30, photo);
        }, _ => Task.CompletedTask);
        using var incoming = await accepting.WaitAsync(TimeSpan.FromSeconds(10));
        using var server = Connection.ForIncoming(incoming, serverId);
        server.Start(() => Task.CompletedTask, (type, body) =>
        {
            if (type == 0x20) offered.TrySetResult();
            if (type == 0x30) received.TrySetResult(body);
            return Task.CompletedTask;
        }, _ => Task.CompletedTask);
        await offered.Task.WaitAsync(TimeSpan.FromSeconds(10));
        // Reproduce a user accepting after the receive loop has resumed waiting.
        await Task.Delay(100);
        await server.SendAsync(0x21, new byte[] { 1 }).WaitAsync(TimeSpan.FromSeconds(3));
        Assert.Equal(photo, await received.Task.WaitAsync(TimeSpan.FromSeconds(10)));
    }

    [Fact]
    public async Task WrongAdvertisedFingerprintFailsBeforeApplicationReady()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var accepting = listener.AcceptTcpClientAsync();
        var closed = new TaskCompletionSource<Exception?>(TaskCreationOptions.RunContinuationsAsynchronously);
        var ready = false;
        using var client = Connection.ForOutgoing("127.0.0.1", ((IPEndPoint)listener.LocalEndpoint).Port, NewIdentity(), new string('0', 32));
        client.Start(() => { ready = true; return Task.CompletedTask; }, (_, _) => Task.CompletedTask,
            error => { closed.TrySetResult(error); return Task.CompletedTask; });
        using var incoming = await accepting.WaitAsync(TimeSpan.FromSeconds(10));
        using var server = Connection.ForIncoming(incoming, NewIdentity());
        server.Start(() => Task.CompletedTask, (_, _) => Task.CompletedTask, _ => Task.CompletedTask);
        Assert.NotNull(await closed.Task.WaitAsync(TimeSpan.FromSeconds(15)));
        Assert.False(ready);
    }

    [Theory]
    [InlineData(SslProtocols.Tls12, "meshdrop/1", true)]
    [InlineData(SslProtocols.Tls13, "wrong-protocol", true)]
    [InlineData(SslProtocols.Tls13, null, true)]
    [InlineData(SslProtocols.Tls13, "meshdrop/1", false)]
    public async Task ServerRejectsDowngradeWrongAlpnAndMissingIdentity(SslProtocols version, string? alpn, bool sendIdentity)
    {
        using var ephemeral = TransportIdentity.Create(NewIdentity());
        using var certificate = new X509Certificate2(ephemeral.Export(X509ContentType.Pfx),
            (string?)null, X509KeyStorageFlags.UserKeySet | X509KeyStorageFlags.Exportable);
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        using var client = new TcpClient();
        var connecting = client.ConnectAsync(IPAddress.Loopback, ((IPEndPoint)listener.LocalEndpoint).Port);
        using var server = await listener.AcceptTcpClientAsync();
        await connecting;
        using var tls = new SecureTransport(NewIdentity(), null);
        var accept = Task.Run(() => tls.Authenticate(server.GetStream(), true));
        using var ssl = new SslStream(client.GetStream(), false, (_, cert, _, _) => cert is not null,
            (_, _, _, _, _) => sendIdentity ? certificate : null!);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        try
        {
            await ssl.AuthenticateAsClientAsync(new SslClientAuthenticationOptions
            {
                TargetHost = "meshdrop", EnabledSslProtocols = version,
                ApplicationProtocols = alpn is null ? null : new() { new(alpn) },
                ClientCertificates = sendIdentity ? new() { certificate } : null,
                AllowTlsResume = false
            }, timeout.Token);
        }
        catch (AuthenticationException) { }
        catch (IOException) { }
        var failure = await Record.ExceptionAsync(async () => await accept.WaitAsync(timeout.Token));
        Assert.NotNull(failure);
        Assert.IsNotType<OperationCanceledException>(failure);
        client.Close(); server.Close();
    }

    [Fact]
    public async Task PlaintextIsRejectedBeforeReady()
    {
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        using var client = new TcpClient();
        var connecting = client.ConnectAsync(IPAddress.Loopback, ((IPEndPoint)listener.LocalEndpoint).Port);
        using var accepted = await listener.AcceptTcpClientAsync();
        await connecting;
        using var server = Connection.ForIncoming(accepted, NewIdentity());
        var closed = new TaskCompletionSource<Exception?>(TaskCreationOptions.RunContinuationsAsynchronously);
        var ready = false;
        server.Start(() => { ready = true; return Task.CompletedTask; }, (_, _) => Task.CompletedTask,
            error => { closed.TrySetResult(error); return Task.CompletedTask; });
        await client.GetStream().WriteAsync(Encoding.UTF8.GetBytes("plaintext HELLO"));
        Assert.NotNull(await closed.Task.WaitAsync(TimeSpan.FromSeconds(10)));
        Assert.False(ready);
    }

    [Fact]
    public async Task GatewayUsesTLS13AndHttp11WithIndependentClient()
    {
        using var key = RSA.Create(2048);
        var request = new CertificateRequest("CN=localhost", key, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
        using var certificate = request.CreateSelfSigned(DateTimeOffset.UtcNow.AddMinutes(-5), DateTimeOffset.UtcNow.AddDays(1));
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        using var client = new TcpClient();
        var connecting = client.ConnectAsync(IPAddress.Loopback, ((IPEndPoint)listener.LocalEndpoint).Port);
        using var server = await listener.AcceptTcpClientAsync();
        await connecting;
        using var tls = new GatewayTls(server.GetStream());
        var accept = Task.Run(() => tls.Authenticate(certificate));
        using var ssl = new SslStream(client.GetStream(), false,
            (_, peer, _, _) => peer?.GetRawCertData().SequenceEqual(certificate.RawData) == true);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(10));
        await ssl.AuthenticateAsClientAsync(new SslClientAuthenticationOptions
        {
            TargetHost = "localhost", EnabledSslProtocols = SslProtocols.Tls13,
            ApplicationProtocols = new() { SslApplicationProtocol.Http2, SslApplicationProtocol.Http11 }
        }, timeout.Token);
        var stream = await accept.WaitAsync(timeout.Token);
        Assert.Equal(SslProtocols.Tls13, ssl.SslProtocol);
        Assert.Equal(SslApplicationProtocol.Http11, ssl.NegotiatedApplicationProtocol);
        await stream.WriteAsync(Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK"), timeout.Token);
        var response = new byte[100];
        var count = await ssl.ReadAsync(response, timeout.Token);
        Assert.EndsWith("\r\n\r\nOK", Encoding.ASCII.GetString(response, 0, count));
        client.Close(); server.Close();
    }

    // Independent OS TLS implementation verifies our wire format and both roles.
    // Runs on Windows 11 (or a TLS-1.3-capable Linux host); production does not use SChannel.
    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public async Task InteroperatesWithSystemTLS13(bool managedServer)
    {
        var managedId = NewIdentity();
        var systemId = NewIdentity();
        using var ephemeral = TransportIdentity.Create(systemId);
        // SChannel needs a key container, unlike the production managed TLS stack.
        using var certificate = new X509Certificate2(ephemeral.Export(X509ContentType.Pfx),
            (string?)null, X509KeyStorageFlags.UserKeySet | X509KeyStorageFlags.Exportable);
        using var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        using var tcpClient = new TcpClient();
        var connecting = tcpClient.ConnectAsync(IPAddress.Loopback, ((IPEndPoint)listener.LocalEndpoint).Port);
        using var tcpServer = await listener.AcceptTcpClientAsync();
        await connecting;
        using var tls = new SecureTransport(managedId, managedServer ? null : systemId.Fingerprint);
        var managedTask = Task.Run(() => tls.Authenticate((managedServer ? tcpServer : tcpClient).GetStream(), managedServer));
        using var system = new SslStream((managedServer ? tcpClient : tcpServer).GetStream(), false,
            (_, peer, _, _) => peer != null && TransportIdentity.Verify(peer.GetRawCertData()) == managedId.Fingerprint,
            (_, _, _, _, _) => certificate);
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(15));
        if (managedServer)
            await system.AuthenticateAsClientAsync(new SslClientAuthenticationOptions
            {
                TargetHost = "meshdrop", EnabledSslProtocols = SslProtocols.Tls13,
                ApplicationProtocols = new() { new("meshdrop/1") },
                ClientCertificates = new() { certificate }, AllowTlsResume = false
            }, timeout.Token);
        else
            await system.AuthenticateAsServerAsync(new SslServerAuthenticationOptions
            {
                ServerCertificate = certificate, EnabledSslProtocols = SslProtocols.Tls13,
                ApplicationProtocols = new() { new("meshdrop/1") },
                ClientCertificateRequired = true, AllowTlsResume = false
            }, timeout.Token);
        var managed = await managedTask.WaitAsync(timeout.Token); // owned by SecureTransport
        Assert.Equal(systemId.Fingerprint, tls.AuthenticatedFingerprint);
        Assert.Equal(SslProtocols.Tls13, system.SslProtocol);
        await system.WriteAsync(new byte[] { 42 }, timeout.Token);
        var buffer = new byte[1];
        Assert.Equal(1, await managed.ReadAsync(buffer, timeout.Token));
        Assert.Equal(42, buffer[0]);
        await managed.WriteAsync(new byte[] { 43 }, timeout.Token);
        Assert.Equal(1, await system.ReadAsync(buffer, timeout.Token));
        Assert.Equal(43, buffer[0]);
        tcpServer.Close(); tcpClient.Close();
    }
}
