package com.welape.meshdrop.transport

import android.content.Context
import android.net.Uri
import android.util.Log
import com.welape.meshdrop.data.Device
import com.welape.meshdrop.data.DeviceOS
import com.welape.meshdrop.data.HistoryItem
import com.welape.meshdrop.data.HistoryKind
import com.welape.meshdrop.data.TransferDirection
import com.welape.meshdrop.data.TransferStatus
import com.welape.meshdrop.protocol.MessageCodec
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import java.io.File
import java.util.UUID

/**
 * 发送 / 接收历史的磁盘持久化。
 *
 * 镜像 [ResumeStore] / TrustStore 范式：明文 JSON 落到 `context.filesDir/history.json`，
 * 引擎启动时 [load] 进内存、每次历史新增 / 状态更新后 [save] 整表覆盖写。
 *
 * 为什么不直接给 [HistoryItem] 加 `@Serializable`：它内含运行时类型（`Uri`、`OutputStream`
 * 关联的进行中态、对端 `Device` 的 host/port 这些只在当前会话有效的字段），直接序列化既不可行也无意义。
 * 因此这里把每条历史拍成稳定的 [HistoryRecord] 快照——对端只留 `{fp,name,os}`（对端可能已离线，
 * 历史展示用快照即可），文件 `Uri` 存成字符串以便重发 / 打开仍可用。
 */
class HistoryStore(private val file: File) {
    private val mutex = Mutex()

    /** 历史上限：超出截断最旧，防文件无限增长。语义与 Apple / 桌面端一致。 */
    private val limit = 500

    /**
     * 读盘并还原成内存历史列表（最新在前，与引擎内存表同序）。
     *
     * @param interruptedReason 对「上次进程退出时仍处于进行中态」的历史，回填的失败原因文案
     *        （由调用方传入已本地化的字符串）。原因见 [PersistedStatus.fromStatus] 的 normalize 注释。
     */
    suspend fun load(interruptedReason: String): List<HistoryItem> = mutex.withLock {
        if (!file.exists()) return emptyList()
        val records = try {
            MessageCodec.json.decodeFromString(SERIALIZER, file.readText())
        } catch (e: Exception) {
            Log.e(TAG, "load failed", e)
            return emptyList()
        }
        records.mapNotNull { it.toHistoryItem(interruptedReason) }
    }

    /** 整表覆盖写。调用方传入当前内存历史（最新在前）；这里截断到 [limit] 条最新后落盘。 */
    suspend fun save(items: List<HistoryItem>) = mutex.withLock {
        val records = items.take(limit).map { HistoryRecord.fromItem(it) }
        try {
            file.parentFile?.mkdirs()
            file.writeText(MessageCodec.json.encodeToString(SERIALIZER, records))
        } catch (e: Exception) {
            Log.e(TAG, "save failed", e)
        }
    }

    companion object {
        private const val TAG = "HistoryStore"
        private val SERIALIZER = ListSerializer(HistoryRecord.serializer())

        fun forContext(context: Context): HistoryStore =
            HistoryStore(File(context.filesDir, "history.json"))
    }
}

// MARK: - 序列化模型

/** 历史落盘用的稳定形态。所有字段均为可序列化原始类型 / 枚举。 */
@Serializable
private data class HistoryRecord(
    val id: String,
    val peer: PeerSnapshot,
    val direction: TransferDirection,
    val kind: PersistedKind,
    val status: PersistedStatus,
    val createdAt: Long,
) {
    fun toHistoryItem(interruptedReason: String): HistoryItem? {
        val uuid = runCatching { UUID.fromString(id) }.getOrNull() ?: return null
        return HistoryItem(
            id = uuid,
            peer = peer.toDevice(),
            direction = direction,
            kind = kind.toKind(),
            status = status.toStatus(interruptedReason),
            createdAt = createdAt,
        )
    }

    companion object {
        fun fromItem(item: HistoryItem): HistoryRecord = HistoryRecord(
            id = item.id.toString(),
            peer = PeerSnapshot.fromDevice(item.peer),
            direction = item.direction,
            kind = PersistedKind.fromKind(item.kind),
            status = PersistedStatus.fromStatus(item.status),
            createdAt = item.createdAt,
        )
    }
}

/** 对端快照：对端可能已离线，历史只需 {fp,name,os}。还原成 [Device] 时 host/port 留空。 */
@Serializable
private data class PeerSnapshot(
    val fp: String,
    val name: String,
    val os: String,
) {
    fun toDevice(): Device = Device(
        // 历史快照没有保留对端 device id；用 fp 兜底，仅供展示，不参与新连接。
        id = fp,
        name = name,
        os = DeviceOS.parse(os) ?: DeviceOS.LINUX,
        model = null,
        fingerprint = fp,
        port = 0,
        protocolVersion = 1,
        host = null,
    )

    companion object {
        fun fromDevice(device: Device): PeerSnapshot = PeerSnapshot(
            fp = device.fingerprint,
            name = device.name,
            os = device.os.raw,
        )
    }
}

/** 文件 / 文本两种 kind 的扁平化形态（用 type 判别）。 */
@Serializable
private data class PersistedKind(
    val type: String,
    // text
    val content: String? = null,
    // file
    val fileName: String? = null,
    val fileSize: Long? = null,
    val uri: String? = null,
) {
    fun toKind(): HistoryKind = when (type) {
        TYPE_FILE -> HistoryKind.File(
            name = fileName.orEmpty(),
            size = fileSize ?: 0L,
            // 存的是字符串；为空表示历史里没有可用 uri（如对端发来的快照）。
            uri = uri?.let { runCatching { Uri.parse(it) }.getOrNull() },
        )
        else -> HistoryKind.Text(content.orEmpty())
    }

    companion object {
        const val TYPE_TEXT = "text"
        const val TYPE_FILE = "file"

        fun fromKind(kind: HistoryKind): PersistedKind = when (kind) {
            is HistoryKind.Text -> PersistedKind(type = TYPE_TEXT, content = kind.content)
            is HistoryKind.File -> PersistedKind(
                type = TYPE_FILE,
                fileName = kind.name,
                fileSize = kind.size,
                uri = kind.uri?.toString(),
            )
        }
    }
}

/** 传输状态的扁平化形态。进行中态落盘时记原始判别，load 时按需 normalize。 */
@Serializable
private data class PersistedStatus(
    val type: String,
    val reason: String? = null,
) {
    fun toStatus(interruptedReason: String): TransferStatus = when (type) {
        TYPE_COMPLETED -> TransferStatus.Completed
        TYPE_FAILED -> TransferStatus.Failed(reason.orEmpty())
        TYPE_CANCELED -> TransferStatus.Canceled
        // 进行中态（Pending / WaitingApproval / Transferring）无法跨进程重启续上：
        // 不能把临时态写死成 Completed，也不该让 UI 永远卡在「传输中」的假进度条上。
        // 因此 load 时一律 normalize 成「连接中断」失败态，与 closeContext 对意外断开的处理一致。
        else -> TransferStatus.Failed(interruptedReason)
    }

    companion object {
        const val TYPE_COMPLETED = "completed"
        const val TYPE_FAILED = "failed"
        const val TYPE_CANCELED = "canceled"
        const val TYPE_INTERRUPTED = "interrupted"

        fun fromStatus(status: TransferStatus): PersistedStatus = when (status) {
            is TransferStatus.Completed -> PersistedStatus(TYPE_COMPLETED)
            is TransferStatus.Failed -> PersistedStatus(TYPE_FAILED, status.reason)
            is TransferStatus.Canceled -> PersistedStatus(TYPE_CANCELED)
            // 进行中态：记成 interrupted 占位，load 时再 normalize（见 toStatus）。
            is TransferStatus.Pending,
            is TransferStatus.WaitingApproval,
            is TransferStatus.Transferring -> PersistedStatus(TYPE_INTERRUPTED)
        }
    }
}
