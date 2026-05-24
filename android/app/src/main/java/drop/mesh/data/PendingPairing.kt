package drop.mesh.data

import java.util.UUID

/** 等待用户决定的入站连接。 */
data class PendingPairing(
    val id: UUID = UUID.randomUUID(),
    val peer: Device,
    val receivedAt: Long = System.currentTimeMillis(),
)

enum class PairingDecision { REJECT, ALLOW_ONCE, TRUST }
