package drop.mesh.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Shield
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import drop.mesh.data.PairingDecision
import drop.mesh.data.PendingPairing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PairingSheet(pending: PendingPairing, onDismiss: () -> Unit) {
    val engine = LocalEngine.current
    val sheetState = rememberModalBottomSheetState()

    ModalBottomSheet(
        onDismissRequest = { /* 强制选择，禁掉手势 */ },
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Shield,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(36.dp),
                )
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(
                        "${pending.peer.name} 想要连接",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                    )
                    Text(
                        "请确认指纹与对方设备一致再放行",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }

            Surface(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(12.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text("指纹", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.size(4.dp))
                    Text(
                        pending.peer.humanFingerprint,
                        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
                        fontFamily = FontFamily.Monospace,
                    )
                }
            }

            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                Button(
                    onClick = {
                        engine.respondToPairing(pending.id, PairingDecision.TRUST)
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("允许并记住") }

                OutlinedButton(
                    onClick = {
                        engine.respondToPairing(pending.id, PairingDecision.ALLOW_ONCE)
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("允许一次") }

                OutlinedButton(
                    onClick = {
                        engine.respondToPairing(pending.id, PairingDecision.REJECT)
                        onDismiss()
                    },
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    ),
                ) { Text("拒绝") }
            }
        }
    }
}
