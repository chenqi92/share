package com.welape.meshdrop.transport

import android.content.Context
import android.util.Log
import com.welape.meshdrop.protocol.MessageCodec
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import java.io.File

/**
 * 中断的接收任务进度记录。
 *
 * 以 `(peerFingerprint, sha256)` 作为去重键 — 不依赖 transfer_id，
 * 这样对端在断开后即使生成新 transfer_id（用户从历史重发），只要文件内容一致，
 * 接收端依旧能定位到之前写到一半的本地文件。
 */
@Serializable
data class ResumeRecord(
    val peerFingerprint: String,
    val transferId: String,
    val fileName: String,
    val fileSize: Long,
    val sha256: String,
    val savedPath: String,
    val bytesDone: Long,
    val updatedAt: Long,
) {
    val key: String get() = makeKey(peerFingerprint, sha256)

    companion object {
        fun makeKey(fp: String, sha256: String): String = "$fp:$sha256"
    }
}

/**
 * 接收方持久化的「中断进度」库。
 *
 * v0.1：明文 JSON，落到 `context.filesDir/resume.json`。
 * 完成或校验失败时调用方负责 [clear]；中断（连接异常关闭）时保留记录。
 */
class ResumeStore(private val file: File) {
    private val mutex = Mutex()
    private val records: MutableMap<String, ResumeRecord> = load()

    suspend fun find(peerFingerprint: String, sha256: String): ResumeRecord? = mutex.withLock {
        records[ResumeRecord.makeKey(peerFingerprint, sha256)]
    }

    suspend fun upsert(record: ResumeRecord) = mutex.withLock {
        records[record.key] = record
        persist()
    }

    suspend fun clear(peerFingerprint: String, sha256: String) = mutex.withLock {
        records.remove(ResumeRecord.makeKey(peerFingerprint, sha256))
        persist()
    }

    suspend fun snapshot(): List<ResumeRecord> = mutex.withLock {
        records.values.toList()
    }

    private fun persist() {
        try {
            file.parentFile?.mkdirs()
            val json = MessageCodec.json.encodeToString(SERIALIZER, records)
            file.writeText(json)
        } catch (e: Exception) {
            Log.e(TAG, "persist failed", e)
        }
    }

    private fun load(): MutableMap<String, ResumeRecord> {
        if (!file.exists()) return mutableMapOf()
        return try {
            MessageCodec.json.decodeFromString(SERIALIZER, file.readText()).toMutableMap()
        } catch (e: Exception) {
            Log.e(TAG, "load failed", e)
            mutableMapOf()
        }
    }

    companion object {
        private const val TAG = "ResumeStore"
        private val SERIALIZER = MapSerializer(String.serializer(), ResumeRecord.serializer())

        fun forContext(context: Context): ResumeStore = ResumeStore(File(context.filesDir, "resume.json"))
    }
}
