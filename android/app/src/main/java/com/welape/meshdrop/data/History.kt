package com.welape.meshdrop.data

import android.net.Uri
import java.util.UUID

enum class TransferDirection { OUTGOING, INCOMING }

sealed interface HistoryKind {
    data class Text(val content: String) : HistoryKind
    data class File(val name: String, val size: Long, val uri: Uri?) : HistoryKind
}

sealed interface TransferStatus {
    data object Pending : TransferStatus
    data object WaitingApproval : TransferStatus
    data class Transferring(val bytesDone: Long, val bytesTotal: Long) : TransferStatus
    data object Completed : TransferStatus
    data class Failed(val reason: String) : TransferStatus
    data object Canceled : TransferStatus
}

data class HistoryItem(
    val id: UUID = UUID.randomUUID(),
    val peer: Device,
    val direction: TransferDirection,
    val kind: HistoryKind,
    val status: TransferStatus,
    val createdAt: Long = System.currentTimeMillis(),
)

/**
 * 收到的剪贴板推送条目（显式推送，非后台同步）。见 protocol/messages.md §0x11。
 * kind ∈ {text|link|code}，用于 UI 区分渲染。
 */
data class ClipboardEntry(
    val id: UUID = UUID.randomUUID(),
    val peerName: String,
    val content: String,
    val kind: String,
    val receivedAt: Long = System.currentTimeMillis(),
)

/** 进行中传输的实时指标。仅在 Transferring 阶段有意义，进入 terminal 时清掉。 */
data class TransferMetrics(
    /** 平滑后的字节 / 秒。0 表示未收到足够样本。 */
    val bytesPerSec: Double,
    /** 剩余时间（秒）；速率为 0 或 total<=done 时为 null。 */
    val etaSeconds: Double?,
)
