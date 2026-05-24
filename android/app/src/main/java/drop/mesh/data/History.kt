package drop.mesh.data

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
