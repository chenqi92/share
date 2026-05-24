package com.welape.meshdrop.protocol

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID

@Serializable
data class HelloMessage(
    val id: String,
    val name: String,
    val os: String,
    val model: String?,
    val fp: String,
    val protocol_versions: List<Int>,
)

@Serializable
data class HelloAckMessage(
    val id: String,
    val name: String,
    val os: String,
    val model: String?,
    val fp: String,
    val protocol_versions: List<Int>,
    val selected_version: Int,
)

@Serializable
data class TextMessage(
    val id: String,
    val content: String,
    val ts: Long,
)

@Serializable
data class FileMeta(
    val index: Int,
    val name: String,
    val size: Long,
    val sha256: String,
)

@Serializable
data class FileOfferMessage(
    val transfer_id: String,
    val files: List<FileMeta>,
)

@Serializable
data class FileAcceptMessage(
    val transfer_id: String,
    val index: Int,
    val resume_offset: Long,
)

@Serializable
data class FileRejectMessage(
    val transfer_id: String,
    val index: Int,
    val reason: String,
)

@Serializable
data class FileCompleteMessage(
    val transfer_id: String,
    val index: Int,
)

@Serializable
data class FileCancelMessage(
    val transfer_id: String,
    val index: Int? = null,
    val reason: String,
)

object MessageCodec {
    val json: Json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = false
    }

    inline fun <reified T> encode(value: T): ByteArray =
        json.encodeToString(kotlinx.serialization.serializer<T>(), value).toByteArray(Charsets.UTF_8)

    inline fun <reified T> decode(body: ByteArray): T =
        json.decodeFromString(kotlinx.serialization.serializer<T>(), body.toString(Charsets.UTF_8))
}

/**
 * FILE_CHUNK 的二进制头部 + 数据。规范见 protocol/messages.md。
 *
 * ```
 * | transfer_id (16) | index (u32 BE) | offset (u64 BE) | data ... |
 * ```
 */
data class FileChunkHeader(
    val transferId: UUID,
    val index: Int,
    val offset: Long,
) {
    companion object {
        const val SIZE = 16 + 4 + 8

        fun encode(header: FileChunkHeader, data: ByteArray): ByteArray {
            val buf = ByteBuffer.allocate(SIZE + data.size).order(ByteOrder.BIG_ENDIAN)
            buf.putLong(header.transferId.mostSignificantBits)
            buf.putLong(header.transferId.leastSignificantBits)
            buf.putInt(header.index)
            buf.putLong(header.offset)
            buf.put(data)
            return buf.array()
        }

        fun decode(body: ByteArray): Pair<FileChunkHeader, ByteArray>? {
            if (body.size < SIZE) return null
            val buf = ByteBuffer.wrap(body).order(ByteOrder.BIG_ENDIAN)
            val msb = buf.long
            val lsb = buf.long
            val index = buf.int
            val offset = buf.long
            val data = body.copyOfRange(SIZE, body.size)
            return Pair(FileChunkHeader(UUID(msb, lsb), index, offset), data)
        }
    }
}
