package com.welape.meshdrop.protocol

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.UUID

/**
 * 跑 protocol/testdata/frames/*.json 黄金向量 —— decoder 方向断言。
 * 保证 Android 端能正确解析其它端按 spec 编出来的字节。
 *
 * 与 Apple ProtocolTestVectorsTests / Linux protocol_test_vectors 同一份向量，
 * 跨端字节兼容的真值保险。
 */
class ProtocolTestVectorsTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun testdataDir(): File {
        // app/src/test/.../ProtocolTestVectorsTest.kt → repo 根 / protocol/testdata/frames
        // CWD 在 Android 单测 JVM 里是 android/app/，所以相对路径用 ../../protocol/testdata
        val base = File("../protocol/testdata/frames").absoluteFile
        if (base.exists()) return base
        // 备路：直接绝对 fallback
        return File("../../protocol/testdata/frames").absoluteFile
    }

    private fun loadSpec(name: String): JsonObject =
        json.parseToJsonElement(File(testdataDir(), name).readText()).let {
            it as JsonObject
        }

    private fun fromHex(hex: String): ByteArray {
        val out = ByteArray(hex.length / 2)
        for (i in out.indices) {
            out[i] = hex.substring(i * 2, i * 2 + 2).toInt(16).toByte()
        }
        return out
    }

    private fun decodeFrame(bytes: ByteArray): Pair<Byte, ByteArray> {
        val r = Frame.decode(bytes, 0, bytes.size)
        assertTrue("expected Decoded, got $r", r is Frame.DecodeResult.Decoded)
        val d = r as Frame.DecodeResult.Decoded
        return Pair(d.type, d.body)
    }

    private fun frameHex(spec: JsonObject): ByteArray =
        fromHex(spec["frame_bytes_hex"]!!.jsonPrimitive.contentOrNull!!)

    // ─── HELLO / HELLO_ACK ─────────────────────────────────────────

    @Test
    fun helloMinimalVectorDecodes() {
        val spec = loadSpec("hello-minimal.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.HELLO, ty)
        val msg = MessageCodec.decode<HelloMessage>(body)
        assertEquals("0123456789abcdef0123456789abcdef", msg.id)
        assertEquals("测试设备", msg.name)
        assertEquals("macos", msg.os)
        assertEquals("00112233445566778899aabbccddeeff", msg.fp)
        assertEquals(listOf(1), msg.protocol_versions)
    }

    @Test
    fun helloAckWithModelVectorDecodes() {
        val spec = loadSpec("hello-ack-with-model.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.HELLO_ACK, ty)
        val msg = MessageCodec.decode<HelloAckMessage>(body)
        assertEquals("iPhone 测试机", msg.name)
        assertEquals("ios", msg.os)
        assertEquals("iPhone17,1", msg.model)
        assertEquals(1, msg.selected_version)
    }

    // ─── TEXT ───────────────────────────────────────────────────────

    @Test
    fun textZhEmojiVectorDecodes() {
        val spec = loadSpec("text-zh-emoji.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.TEXT, ty)
        val msg = MessageCodec.decode<TextMessage>(body)
        assertEquals("550e8400-e29b-41d4-a716-446655440000", msg.id)
        assertEquals("你好 · world 🌧️", msg.content)
        assertEquals(1716537600L, msg.ts)
    }

    // ─── FILE_OFFER / ACCEPT / REJECT / COMPLETE / CANCEL ──────────

    @Test
    fun fileOfferSingleVectorDecodes() {
        val spec = loadSpec("file-offer-single.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.FILE_OFFER, ty)
        val msg = MessageCodec.decode<FileOfferMessage>(body)
        assertEquals("550e8400-e29b-41d4-a716-446655440001", msg.transfer_id)
        assertEquals(1, msg.files.size)
        assertEquals("report.pdf", msg.files[0].name)
        assertEquals(1_048_576L, msg.files[0].size)
        assertEquals(64, msg.files[0].sha256.length)
    }

    @Test
    fun fileAcceptFreshVectorDecodes() {
        val spec = loadSpec("file-accept-fresh.json")
        val (_, body) = decodeFrame(frameHex(spec))
        val msg = MessageCodec.decode<FileAcceptMessage>(body)
        assertEquals(0L, msg.resume_offset)
    }

    @Test
    fun fileAcceptResumeVectorDecodes() {
        val spec = loadSpec("file-accept-resume.json")
        val (_, body) = decodeFrame(frameHex(spec))
        val msg = MessageCodec.decode<FileAcceptMessage>(body)
        assertEquals(524288L, msg.resume_offset)
    }

    @Test
    fun fileRejectVectorDecodes() {
        val spec = loadSpec("file-reject-user-declined.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.FILE_REJECT, ty)
        val msg = MessageCodec.decode<FileRejectMessage>(body)
        assertEquals("user_declined", msg.reason)
    }

    @Test
    fun fileCompleteVectorDecodes() {
        val spec = loadSpec("file-complete.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.FILE_COMPLETE, ty)
        val msg = MessageCodec.decode<FileCompleteMessage>(body)
        assertEquals(0, msg.index)
    }

    @Test
    fun fileCancelWholeVectorDecodes() {
        val spec = loadSpec("file-cancel-whole.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.FILE_CANCEL, ty)
        val msg = MessageCodec.decode<FileCancelMessage>(body)
        assertEquals("550e8400-e29b-41d4-a716-446655440001", msg.transfer_id)
        assertNull(msg.index)
        assertEquals("user_canceled", msg.reason)
    }

    // ─── FILE_CHUNK (binary) ───────────────────────────────────────

    @Test
    fun fileChunkMinVectorDecodes() {
        val spec = loadSpec("file-chunk-min.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.FILE_CHUNK, ty)
        val pair = FileChunkHeader.decode(body)
        assertNotNull(pair)
        val (header, data) = pair!!
        assertEquals(UUID.fromString("550e8400-e29b-41d4-a716-446655440001"), header.transferId)
        assertEquals(0, header.index)
        assertEquals(0L, header.offset)
        assertEquals("hello world", String(data, Charsets.UTF_8))
    }

    // ─── PING ──────────────────────────────────────────────────────

    @Test
    fun pingVectorDecodes() {
        val spec = loadSpec("ping.json")
        val (ty, body) = decodeFrame(frameHex(spec))
        assertEquals(MessageType.PING, ty)
        assertEquals("{}", String(body, Charsets.UTF_8))
    }
}
