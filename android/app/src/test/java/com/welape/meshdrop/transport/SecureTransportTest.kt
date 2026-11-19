package com.welape.meshdrop.transport

import com.welape.meshdrop.data.Identity
import com.welape.meshdrop.data.IdentityStore
import com.welape.meshdrop.protocol.Frame
import com.welape.meshdrop.protocol.MessageType
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test
import java.io.DataInputStream
import java.io.IOException
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class SecureTransportTest {
    private fun identity(): Identity {
        val keys = IdentityStore.generate()
        return Identity(UUID.randomUUID().toString(), keys, IdentityStore.computeFingerprint(keys.public))
    }

    @Test fun certificateRenewalKeepsIdentityAndExpiredProofFails() {
        val identity = identity()
        val now = 1_800_000_000_000L
        val original = TransportCertificate.create(identity, now).der
        val renewed = TransportCertificate.create(identity, now).der
        assertFalse(original.contentEquals(renewed))
        assertEquals(identity.fingerprint, TransportCertificate.verify(original, now))
        assertEquals(identity.fingerprint, TransportCertificate.verify(renewed, now))
        val modified = original.copyOf().apply { this[lastIndex] = (last().toInt() xor 1).toByte() }
        assertThrows(IllegalArgumentException::class.java) { TransportCertificate.verify(modified, now) }
        assertThrows(IllegalArgumentException::class.java) {
            TransportCertificate.verify(original, now + TimeUnit.DAYS.toMillis(31))
        }
    }

    @Test fun authenticatesBothPeersAndTransfersFramesAcrossTlsRecords() {
        val client = identity()
        val server = identity()
        val payload = ByteArray(131071) { (it % 251).toByte() }
        val frame = Frame.encode(MessageType.FILE_CHUNK, payload)
        val executor = Executors.newSingleThreadExecutor()
        try {
            ServerSocket(0, 1, InetAddress.getLoopbackAddress()).use { listener ->
                val echo = executor.submit {
                    listener.accept().use { socket ->
                        socket.soTimeout = 10_000
                        val tls = SecureTransport.authenticate(socket, server, null)
                        assertEquals(client.fingerprint, tls.fingerprint)
                        val wire = ByteArray(frame.size)
                        DataInputStream(tls.input).readFully(wire)
                        assertArrayEquals(frame, wire)
                        tls.output.write(wire)
                        tls.output.flush()
                    }
                }
                Socket(listener.inetAddress, listener.localPort).use { socket ->
                    socket.soTimeout = 10_000
                    val tls = SecureTransport.authenticate(socket, client, server.fingerprint)
                    assertEquals(server.fingerprint, tls.fingerprint)
                    tls.output.write(frame)
                    tls.output.flush()
                    val returned = ByteArray(frame.size)
                    DataInputStream(tls.input).readFully(returned)
                    val decoded = Frame.decode(returned, 0, returned.size) as Frame.DecodeResult.Decoded
                    assertEquals(MessageType.FILE_CHUNK, decoded.type)
                    assertArrayEquals(payload, decoded.body)
                }
                echo.get(10, TimeUnit.SECONDS)
            }
        } finally {
            executor.shutdownNow()
        }
    }

    @Test fun rejectsUnmatchedAdvertisedFingerprintBeforeApplicationData() {
        val server = identity()
        val client = identity()
        val executor = Executors.newSingleThreadExecutor()
        try {
            ServerSocket(0, 1, InetAddress.getLoopbackAddress()).use { listener ->
                val incoming = executor.submit {
                    listener.accept().use { socket ->
                        socket.soTimeout = 10_000
                        assertThrows(IOException::class.java) { SecureTransport.authenticate(socket, server, null) }
                    }
                }
                Socket(listener.inetAddress, listener.localPort).use { socket ->
                    socket.soTimeout = 10_000
                    assertThrows(IOException::class.java) {
                        SecureTransport.authenticate(socket, client, client.fingerprint)
                    }
                }
                incoming.get(10, TimeUnit.SECONDS)
            }
        } finally {
            executor.shutdownNow()
        }
    }
}
