package com.welape.meshdrop.transport

import com.welape.meshdrop.data.Identity
import org.bouncycastle.crypto.util.PrivateKeyFactory
import org.bouncycastle.tls.AlertDescription
import org.bouncycastle.tls.Certificate
import org.bouncycastle.tls.CertificateEntry
import org.bouncycastle.tls.CertificateRequest
import org.bouncycastle.tls.CipherSuite
import org.bouncycastle.tls.DefaultTlsClient
import org.bouncycastle.tls.DefaultTlsServer
import org.bouncycastle.tls.HashAlgorithm
import org.bouncycastle.tls.ProtocolName
import org.bouncycastle.tls.ProtocolVersion
import org.bouncycastle.tls.SignatureAlgorithm
import org.bouncycastle.tls.SignatureAndHashAlgorithm
import org.bouncycastle.tls.TlsAuthentication
import org.bouncycastle.tls.TlsClientProtocol
import org.bouncycastle.tls.TlsContext
import org.bouncycastle.tls.TlsCredentials
import org.bouncycastle.tls.TlsFatalAlert
import org.bouncycastle.tls.TlsServerCertificate
import org.bouncycastle.tls.TlsServerProtocol
import org.bouncycastle.tls.crypto.TlsCryptoParameters
import org.bouncycastle.tls.crypto.impl.bc.BcDefaultTlsCredentialedSigner
import org.bouncycastle.tls.crypto.impl.bc.BcTlsCrypto
import java.io.InputStream
import java.io.OutputStream
import java.net.Socket
import java.security.SecureRandom
import java.util.Vector

internal class SecureTransport private constructor(identity: Identity, private val expectedFingerprint: String?) {
    private val crypto = BcTlsCrypto(SecureRandom())
    private val material = TransportCertificate.create(identity)
    private var peerFingerprint: String? = null

    data class Session(val input: InputStream, val output: OutputStream, val fingerprint: String)

    companion object {
        private val alpn = ProtocolName.asUtf8Encoding("meshdrop/1")
        private val signAlgorithm = SignatureAndHashAlgorithm.getInstance(HashAlgorithm.sha256, SignatureAlgorithm.ecdsa)
        private val suites = intArrayOf(CipherSuite.TLS_AES_256_GCM_SHA384, CipherSuite.TLS_CHACHA20_POLY1305_SHA256)

        fun authenticate(socket: Socket, identity: Identity, expectedFingerprint: String?): Session {
            val security = SecureTransport(identity, expectedFingerprint)
            val input = socket.getInputStream()
            val output = socket.getOutputStream()
            val protocol = if (expectedFingerprint == null) {
                TlsServerProtocol(input, output).apply { accept(security.Server()) }
            } else {
                TlsClientProtocol(input, output).apply { connect(security.Client()) }
            }
            return Session(protocol.inputStream, protocol.outputStream, checkNotNull(security.peerFingerprint))
        }
    }

    private fun verify(chain: Certificate) {
        try {
            require(chain.length == 1)
            val fp = TransportCertificate.verify(chain.getCertificateAt(0).encoded)
            require(expectedFingerprint == null || fp.equals(expectedFingerprint, ignoreCase = true))
            peerFingerprint = fp
        } catch (e: Exception) {
            throw TlsFatalAlert(AlertDescription.bad_certificate, e)
        }
    }

    private fun credentials(context: TlsContext): TlsCredentials = BcDefaultTlsCredentialedSigner(
        TlsCryptoParameters(context), crypto, PrivateKeyFactory.createKey(material.privateKey.encoded),
        Certificate(byteArrayOf(), arrayOf(CertificateEntry(crypto.createCertificate(material.der), null))), signAlgorithm,
    )

    private fun completed(context: TlsContext) {
        if (context.securityParametersConnection.applicationProtocol != alpn || peerFingerprint == null) {
            throw TlsFatalAlert(AlertDescription.handshake_failure)
        }
    }

    private inner class Client : DefaultTlsClient(crypto), TlsAuthentication {
        override fun getSupportedVersions() = arrayOf(ProtocolVersion.TLSv13)
        override fun getSupportedCipherSuites() = suites
        override fun getProtocolNames() = Vector(listOf(alpn))
        override fun getAuthentication(): TlsAuthentication = this
        override fun notifyServerCertificate(serverCertificate: TlsServerCertificate) = verify(serverCertificate.certificate)
        override fun getClientCredentials(request: CertificateRequest) = credentials(context)
        override fun notifyHandshakeComplete() {
            super.notifyHandshakeComplete()
            completed(context)
        }
    }

    private inner class Server : DefaultTlsServer(crypto) {
        override fun getSupportedVersions() = arrayOf(ProtocolVersion.TLSv13)
        override fun getSupportedCipherSuites() = suites
        override fun getProtocolNames() = Vector(listOf(alpn))
        override fun getCredentials() = credentials(context)
        override fun getCertificateRequest() = CertificateRequest(byteArrayOf(), Vector(listOf(signAlgorithm)), null, null)
        override fun notifyClientCertificate(clientCertificate: Certificate) = verify(clientCertificate)
        override fun notifyHandshakeComplete() {
            super.notifyHandshakeComplete()
            completed(context)
        }
    }
}
