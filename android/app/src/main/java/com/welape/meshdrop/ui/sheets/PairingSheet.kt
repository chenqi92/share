package com.welape.meshdrop.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.R
import com.welape.meshdrop.data.PairingDecision
import com.welape.meshdrop.data.PendingPairing
import com.welape.meshdrop.mock.MockPendingPairingItem
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk
import kotlin.math.max

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PairingSheet(
    pairing: PendingPairing? = null,
    useMockFallback: Boolean = true,
    onDecision: (PairingDecision) -> Unit = {},
    onClose: () -> Unit,
) {
    val mesh = MeshTheme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
        containerColor = mesh.card,
        contentColor = mesh.textPrimary,
    ) {
        PairingSheetContent(
            pairing = pairing,
            useMockFallback = useMockFallback,
            onDecision = onDecision,
            onClose = onClose,
        )
    }
}

@Composable
fun PairingSheetContent(
    pairing: PendingPairing? = null,
    useMockFallback: Boolean = true,
    onDecision: (PairingDecision) -> Unit = {},
    onClose: () -> Unit = {},
) {
    val mesh = MeshTheme.colors
    val model = pairing?.toPairingSheetModel()
        ?: if (useMockFallback) MockPendingPairingItem.toPairingSheetModel() else null
    androidx.compose.foundation.layout.Column(
        modifier = Modifier
            .background(mesh.card)
            .fillMaxWidth()
            .padding(PaddingValues(horizontal = 22.dp, vertical = 24.dp)),
    ) {
        if (model == null) {
            EmptyPending(stringResource(R.string.pairing_empty), onClose)
            return@Column
        }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.pairing_title),
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 22.sp, color = mesh.textPrimary, letterSpacing = (-0.4).sp,
                    ),
                )
                Spacer(Modifier.weight(1f))
                MeshChip(text = "LAN", tone = ChipTone.OUTLINE, mono = true)
            }
            Text(
                stringResource(R.string.pairing_requested_at, model.receivedAt),
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W400,
                    fontSize = 13.sp, color = mesh.textSecondary,
                ),
            )

            Spacer(Modifier.height(14.dp))

            MonoLabel(stringResource(R.string.pairing_requested_by))
            Text(
                text = "${model.peer} · ${model.deviceName}",
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W600,
                    fontSize = 16.sp, color = mesh.textPrimary,
                ),
            )

            AsciiDivider(label = stringResource(R.string.pairing_section_fingerprint))

            // 指纹分组（4-4 8 组，两行）
            Column {
                val groups = model.fingerprintGroups
                groups.chunked(4).forEach { row ->
                    Text(
                        text = row.joinToString("  ·  "),
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W700,
                            fontSize = 14.sp, color = mesh.textPrimary, letterSpacing = 1.4.sp,
                        ),
                        modifier = Modifier.padding(vertical = 2.dp),
                    )
                }
            }

            AsciiDivider(label = stringResource(R.string.pairing_section_choices))

            // 三个按钮
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                BigActionButton(
                    label = stringResource(R.string.pairing_deny), subtitle = stringResource(R.string.pairing_deny_sub),
                    bg = mesh.surface, fg = mesh.textPrimary,
                    border = mesh.outline, modifier = Modifier.weight(1f),
                    onClick = {
                        onDecision(PairingDecision.REJECT)
                        onClose()
                    },
                )
                BigActionButton(
                    label = stringResource(R.string.pairing_allow_once), subtitle = stringResource(R.string.pairing_allow_once_sub),
                    bg = mesh.card, fg = mesh.textPrimary,
                    border = mesh.textPrimary, modifier = Modifier.weight(1f),
                    onClick = {
                        onDecision(PairingDecision.ALLOW_ONCE)
                        onClose()
                    },
                )
                BigActionButton(
                    label = stringResource(R.string.pairing_trust), subtitle = stringResource(R.string.pairing_trust_sub),
                    bg = Lime, fg = Ink, border = Color.Transparent,
                    modifier = Modifier.weight(1f),
                    onClick = {
                        onDecision(PairingDecision.TRUST)
                        onClose()
                    },
                )
            }
            Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun EmptyPending(message: String, onClose: () -> Unit) {
    val mesh = MeshTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            message,
            style = TextStyle(
                fontFamily = Geist, fontWeight = FontWeight.W600,
                fontSize = 14.sp, color = mesh.textPrimary,
            ),
        )
        BigActionButton(
            label = stringResource(R.string.pairing_close), subtitle = stringResource(R.string.pairing_close_sub),
            bg = mesh.surface, fg = mesh.textPrimary, border = mesh.outline,
            onClick = onClose,
        )
    }
}

private data class PairingSheetModel(
    val peer: String,
    val deviceName: String,
    val fingerprintGroups: List<String>,
    val receivedAt: String,
)

private fun PendingPairing.toPairingSheetModel(): PairingSheetModel {
    val groups = peer.humanFingerprint.split(" ").filter { it.isNotBlank() }
    return PairingSheetModel(
        peer = peer.name.ifBlank { peer.id.take(8) },
        deviceName = peer.model ?: peer.os.raw,
        fingerprintGroups = groups,
        receivedAt = relativeAge(receivedAt),
    )
}

private fun com.welape.meshdrop.mock.MockPendingPairing.toPairingSheetModel(): PairingSheetModel =
    PairingSheetModel(
        peer = peer,
        deviceName = deviceName,
        fingerprintGroups = fingerprintGroups,
        receivedAt = receivedAt,
    )

private fun relativeAge(ts: Long): String {
    val seconds = max(0L, (System.currentTimeMillis() - ts) / 1000)
    return when {
        seconds < 60 -> "${seconds}s ago"
        seconds < 3600 -> "${seconds / 60}m ago"
        else -> "${seconds / 3600}h ago"
    }
}

@Composable
private fun BigActionButton(
    label: String, subtitle: String,
    bg: Color, fg: Color, border: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, border, RoundedCornerShape(14.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(PaddingValues(horizontal = 14.dp, vertical = 14.dp)),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            label,
            style = TextStyle(
                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                fontSize = 15.sp, color = fg,
            ),
        )
        Text(
            subtitle,
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W700,
                fontSize = 9.sp, color = fg.copy(alpha = 0.65f), letterSpacing = 1.4.sp,
            ),
        )
    }
}
