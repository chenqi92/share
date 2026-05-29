package com.welape.meshdrop.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockTransfer
import com.welape.meshdrop.mock.TransferState
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme

/** 下载管理器单行：文件 icon + name + size + 状态行（+ 进行中时进度条 + speed + ETA）。
 *  传入 [onCancel] 且 state 是 SENDING / RECEIVING 时，状态行右侧渲染取消图标。
 *  传入 [onRetry] 且 state 是 FAILED 时，状态行右侧渲染重试按钮。
 *  传入 [onOpen] 且 state 是 DONE && savedFileUri 非空时，状态行右侧渲染 OPEN 按钮。 */
@Composable
fun TransferRow(
    item: MockTransfer,
    modifier: Modifier = Modifier,
    onCancel: (() -> Unit)? = null,
    onRetry: (() -> Unit)? = null,
    onOpen: (() -> Unit)? = null,
) {
    val mesh = MeshTheme.colors
    val (stateLabel, stateColor, stateGlyph) = when (item.state) {
        TransferState.SENDING -> Triple("发送中 · SENDING", mesh.flame, "↑")
        TransferState.RECEIVING -> Triple("接收中 · RECEIVING", mesh.sky, "↓")
        TransferState.DONE -> Triple("已完成 · DONE", LimeDeep, "✓")
        TransferState.QUEUED -> Triple("排队中 · QUEUED", mesh.textTertiary, "·")
        TransferState.FAILED -> Triple(
            item.failReason?.let { "失败 · $it" } ?: "失败 · FAILED",
            mesh.danger, "×",
        )
    }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, mesh.outline, RoundedCornerShape(14.dp))
            .background(mesh.card)
            .padding(PaddingValues(horizontal = 14.dp, vertical = 14.dp)),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            FileGlyph(ext = item.ext, sizeDp = 38.dp)
            Box(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.name,
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W600,
                        fontSize = 14.sp, color = mesh.textPrimary,
                    ),
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
                Box(Modifier.size(2.dp))
                Text(
                    text = "${item.size}  ·  ${item.from} → ${item.to}",
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = mesh.textTertiary,
                    ),
                )
            }
            Box(
                Modifier
                    .size(28.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(stateColor.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stateGlyph,
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W700,
                        fontSize = 14.sp, color = stateColor,
                    ),
                )
            }
        }
        // 状态行 + 进度
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = stateLabel,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W700,
                    fontSize = 10.sp, letterSpacing = 1.6.sp, color = stateColor,
                ),
            )
            if (item.speed != null || item.eta != null) {
                Box(Modifier.weight(1f))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    item.speed?.let {
                        Text(
                            text = it,
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W600,
                                fontSize = 11.sp, color = mesh.textPrimary,
                            ),
                        )
                    }
                    item.eta?.let {
                        Text(
                            text = "ETA $it",
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                                fontSize = 11.sp, color = mesh.textTertiary,
                            ),
                        )
                    }
                }
            } else {
                Box(Modifier.weight(1f))
            }
            if (onCancel != null && (item.state == TransferState.SENDING || item.state == TransferState.RECEIVING)) {
                Box(Modifier.width(8.dp))
                Icon(
                    imageVector = Icons.Filled.Cancel,
                    contentDescription = "取消传输",
                    tint = mesh.flame,
                    modifier = Modifier
                        .size(20.dp)
                        .clickable { onCancel() },
                )
            }
            if (onRetry != null && item.state == TransferState.FAILED) {
                Box(Modifier.width(8.dp))
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .border(0.8.dp, mesh.flame.copy(alpha = 0.4f), RoundedCornerShape(6.dp))
                        .clickable { onRetry() }
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.Filled.Refresh,
                        contentDescription = null,
                        tint = mesh.flame,
                        modifier = Modifier.size(11.dp),
                    )
                    Text(
                        text = "RETRY",
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W700,
                            fontSize = 10.sp, letterSpacing = 1.0.sp, color = mesh.flame,
                        ),
                    )
                }
            }
            if (onOpen != null && item.state == TransferState.DONE) {
                Box(Modifier.width(8.dp))
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(6.dp))
                        .border(0.8.dp, LimeDeep.copy(alpha = 0.5f), RoundedCornerShape(6.dp))
                        .clickable { onOpen() }
                        .padding(horizontal = 8.dp, vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.OpenInNew,
                        contentDescription = null,
                        tint = LimeDeep,
                        modifier = Modifier.size(11.dp),
                    )
                    Text(
                        text = "OPEN",
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W700,
                            fontSize = 10.sp, letterSpacing = 1.0.sp, color = LimeDeep,
                        ),
                    )
                }
            }
        }
        if (item.state == TransferState.SENDING || item.state == TransferState.RECEIVING || item.state == TransferState.DONE) {
            Box(
                Modifier
                    .height(4.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(2.dp))
                    .background(mesh.outline),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(item.progress / 100f)
                        .fillMaxSize()
                        .background(stateColor),
                )
            }
        }
    }
}

@Composable
fun StateDotChip(label: String, glyph: String, color: Color) {
    val mesh = MeshTheme.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(
            Modifier
                .size(16.dp)
                .clip(RoundedCornerShape(8.dp))
                .background(color.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) {
            Text(glyph, style = TextStyle(fontFamily = GeistMono, fontSize = 10.sp, fontWeight = FontWeight.W700, color = color))
        }
        Text(label, style = TextStyle(fontFamily = GeistMono, fontSize = 10.sp, color = mesh.textSecondary, letterSpacing = 1.4.sp, fontWeight = FontWeight.W700))
    }
}
