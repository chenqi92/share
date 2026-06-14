package com.welape.meshdrop.ui.sheets

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.Paper
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
            EmptyPending("暂无配对请求", onClose)
            return@Column
        }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "配对 · Pairing",
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 22.sp, color = mesh.textPrimary, letterSpacing = (-0.4).sp,
                    ),
                )
                Spacer(Modifier.weight(1f))
                MeshChip(text = "LAN", tone = ChipTone.OUTLINE, mono = true)
            }
            Text(
                "对方在 ${model.receivedAt} 请求与你配对",
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W400,
                    fontSize = 13.sp, color = mesh.textSecondary,
                ),
            )

            Spacer(Modifier.height(14.dp))

            // QR + 6 字符 code 二列
            Row(verticalAlignment = Alignment.CenterVertically) {
                FakeQr(sizeDp = 132)
                Spacer(Modifier.width(18.dp))
                Column {
                    MonoLabel("6 字符代码 · PIN")
                    Spacer(Modifier.height(6.dp))
                    Text(
                        text = model.pinCode,
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 36.sp, color = LimeDeep, letterSpacing = 4.sp,
                        ),
                    )
                    Spacer(Modifier.height(8.dp))
                    MonoLabel("REQUESTED BY")
                    Text(
                        text = "${model.peer} · ${model.deviceName}",
                        style = TextStyle(
                            fontFamily = Geist, fontWeight = FontWeight.W600,
                            fontSize = 13.sp, color = mesh.textPrimary,
                        ),
                    )
                }
            }

            AsciiDivider(label = "指纹 · FINGERPRINT (SHA-256/16)")

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

            AsciiDivider(label = "操作 · CHOICES")

            // 三个按钮
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                BigActionButton(
                    label = "拒绝", subtitle = "DENY",
                    bg = mesh.surface, fg = mesh.textPrimary,
                    border = mesh.outline, modifier = Modifier.weight(1f),
                    onClick = {
                        onDecision(PairingDecision.REJECT)
                        onClose()
                    },
                )
                BigActionButton(
                    label = "允许一次", subtitle = "ALLOW ONCE",
                    bg = mesh.card, fg = mesh.textPrimary,
                    border = mesh.textPrimary, modifier = Modifier.weight(1f),
                    onClick = {
                        onDecision(PairingDecision.ALLOW_ONCE)
                        onClose()
                    },
                )
                BigActionButton(
                    label = "信任", subtitle = "TRUST FOREVER",
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
            label = "关闭", subtitle = "CLOSE",
            bg = mesh.surface, fg = mesh.textPrimary, border = mesh.outline,
            onClick = onClose,
        )
    }
}

private data class PairingSheetModel(
    val peer: String,
    val deviceName: String,
    val fingerprintGroups: List<String>,
    val pinCode: String,
    val receivedAt: String,
)

private fun PendingPairing.toPairingSheetModel(): PairingSheetModel {
    val groups = peer.humanFingerprint.split(" ").filter { it.isNotBlank() }
    val shortCode = peer.fingerprint
        .filter { it.isLetterOrDigit() }
        .take(6)
        .uppercase()
        .ifBlank { "------" }
        .chunked(1)
        .joinToString("-")
    return PairingSheetModel(
        peer = peer.name.ifBlank { peer.id.take(8) },
        deviceName = peer.model ?: peer.os.raw,
        fingerprintGroups = groups,
        pinCode = shortCode,
        receivedAt = relativeAge(receivedAt),
    )
}

private fun com.welape.meshdrop.mock.MockPendingPairing.toPairingSheetModel(): PairingSheetModel =
    PairingSheetModel(
        peer = peer,
        deviceName = deviceName,
        fingerprintGroups = fingerprintGroups,
        pinCode = pinCode,
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

/** Fake QR (棋盘 + 角标，纯装饰)。 */
@Composable
private fun FakeQr(sizeDp: Int) {
    val mesh = MeshTheme.colors
    Box(
        Modifier
            .size(sizeDp.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(Paper)
            .border(1.dp, mesh.outline, RoundedCornerShape(8.dp))
            .padding(8.dp),
    ) {
        Canvas(modifier = Modifier.fillMaxWidth().height(sizeDp.dp - 16.dp)) {
            val grid = 21
            val cell = size.minDimension / grid
            // 一个简单 hash 模式：用 (i*7 + j*11) % 3 == 0 之类作为黑格
            for (i in 0 until grid) {
                for (j in 0 until grid) {
                    val on = (i * 7 + j * 11 + 5) % 3 == 0
                    if (on) {
                        drawRect(
                            color = Ink,
                            topLeft = Offset(j * cell, i * cell),
                            size = Size(cell, cell),
                        )
                    }
                }
            }
            // 三个角的定位方框
            listOf(Offset(0f, 0f), Offset(size.width - 7 * cell, 0f), Offset(0f, size.height - 7 * cell)).forEach { o ->
                drawRect(color = Paper, topLeft = o, size = Size(7 * cell, 7 * cell))
                drawRect(color = Ink, topLeft = o, size = Size(7 * cell, cell))
                drawRect(color = Ink, topLeft = o, size = Size(cell, 7 * cell))
                drawRect(color = Ink, topLeft = o + Offset(0f, 6 * cell), size = Size(7 * cell, cell))
                drawRect(color = Ink, topLeft = o + Offset(6 * cell, 0f), size = Size(cell, 7 * cell))
                drawRect(color = Ink, topLeft = o + Offset(2 * cell, 2 * cell), size = Size(3 * cell, 3 * cell))
            }
        }
    }
}
