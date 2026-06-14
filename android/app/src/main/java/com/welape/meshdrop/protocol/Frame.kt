package com.welape.meshdrop.protocol

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 帧编解码。规范见 protocol/transport.md。
 *
 * ```
 * +--------+------+----------------------+
 * | u32 BE | u8   | body (length-1 bytes)|
 * | length | type |                      |
 * +--------+------+----------------------+
 * ```
 */
object Frame {
    const val MAX_LENGTH = 16 * 1024 * 1024  // 16 MiB

    fun encode(type: Byte, body: ByteArray): ByteArray {
        val len = body.size + 1
        require(len in 1..MAX_LENGTH) { "frame length out of range: $len" }
        val out = ByteArray(4 + len)
        ByteBuffer.wrap(out, 0, 4).order(ByteOrder.BIG_ENDIAN).putInt(len)
        out[4] = type
        body.copyInto(out, 5)
        return out
    }

    sealed class DecodeResult {
        data object NeedMore : DecodeResult()
        data class Decoded(val type: Byte, val body: ByteArray, val consumed: Int) : DecodeResult()
        data class LengthOutOfRange(val len: Int) : DecodeResult()
    }

    /** 从 buf[offset, offset+size) 尝试解出一帧。 */
    fun decode(buf: ByteArray, offset: Int, size: Int): DecodeResult {
        if (size < 4) return DecodeResult.NeedMore
        val len = ByteBuffer.wrap(buf, offset, 4).order(ByteOrder.BIG_ENDIAN).int
        if (len < 1 || len > MAX_LENGTH) return DecodeResult.LengthOutOfRange(len)
        val total = 4 + len
        if (size < total) return DecodeResult.NeedMore
        val type = buf[offset + 4]
        val body = buf.copyOfRange(offset + 5, offset + total)
        return DecodeResult.Decoded(type, body, total)
    }
}

/** 协议消息类型常量，对齐 protocol/messages.md。 */
object MessageType {
    const val HELLO: Byte = 0x01
    const val HELLO_ACK: Byte = 0x02
    const val TEXT: Byte = 0x10
    const val CLIPBOARD: Byte = 0x11
    const val FILE_OFFER: Byte = 0x20
    const val FILE_ACCEPT: Byte = 0x21
    const val FILE_REJECT: Byte = 0x22
    const val FILE_COMPLETE: Byte = 0x23
    const val FILE_CANCEL: Byte = 0x25
    const val FILE_CHUNK: Byte = 0x30
    const val PING: Byte = 0xF0.toByte()
    const val PONG: Byte = 0xF1.toByte()

    /** 是否为本协议已定义的 type；用于「未识别 type 丢弃该帧并继续读」（transport.md）的判定。 */
    fun isKnown(t: Byte): Boolean = when (t) {
        HELLO, HELLO_ACK, TEXT, CLIPBOARD, FILE_OFFER, FILE_ACCEPT,
        FILE_REJECT, FILE_COMPLETE, FILE_CANCEL, FILE_CHUNK, PING, PONG -> true
        else -> false
    }
}
