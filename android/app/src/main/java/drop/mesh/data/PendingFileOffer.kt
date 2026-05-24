package drop.mesh.data

import java.text.NumberFormat
import java.util.UUID

/** 等待用户决定的入站文件请求。 */
data class PendingFileOffer(
    val id: UUID,                // = transfer_id
    val peer: Device,
    val fileName: String,
    val fileSize: Long,
    val sha256: String,
    val receivedAt: Long = System.currentTimeMillis(),
) {
    val formattedSize: String
        get() = formatBytes(fileSize)
}

fun formatBytes(n: Long): String {
    if (n < 1024) return "$n B"
    val kb = n / 1024.0
    if (kb < 1024) return "${NumberFormat.getInstance().apply { maximumFractionDigits = 1 }.format(kb)} KB"
    val mb = kb / 1024.0
    if (mb < 1024) return "${NumberFormat.getInstance().apply { maximumFractionDigits = 1 }.format(mb)} MB"
    val gb = mb / 1024.0
    return "${NumberFormat.getInstance().apply { maximumFractionDigits = 2 }.format(gb)} GB"
}
