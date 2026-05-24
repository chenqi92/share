package com.welape.meshdrop.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockMessage
import com.welape.meshdrop.mock.MsgKind
import com.welape.meshdrop.mock.MsgSide
import com.welape.meshdrop.mock.MsgState
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme

@Composable
fun MsgBubble(
    msg: MockMessage,
    modifier: Modifier = Modifier,
) {
    val mesh = MeshTheme.colors
    val isOut = msg.side == MsgSide.OUT
    val bg = if (isOut) mesh.outgoingBubble else mesh.incomingBubble
    val fg = if (isOut) mesh.outgoingText else mesh.incomingText

    val shape = if (isOut) {
        RoundedCornerShape(topStart = 16.dp, topEnd = 6.dp, bottomEnd = 16.dp, bottomStart = 16.dp)
    } else {
        RoundedCornerShape(topStart = 6.dp, topEnd = 16.dp, bottomEnd = 16.dp, bottomStart = 16.dp)
    }

    val (pad, contentPad) = when (msg.kind) {
        MsgKind.TEXT -> 12.dp to PaddingValues(horizontal = 14.dp, vertical = 10.dp)
        MsgKind.FILE -> 10.dp to PaddingValues(horizontal = 12.dp, vertical = 12.dp)
        MsgKind.IMAGE -> 4.dp to PaddingValues(horizontal = 4.dp, vertical = 4.dp)
    }

    Column(
        modifier = modifier.fillMaxWidth(),
        horizontalAlignment = if (isOut) Alignment.End else Alignment.Start,
    ) {
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(shape)
                .background(bg)
                .padding(contentPad),
        ) {
            when (msg.kind) {
                MsgKind.TEXT -> Text(
                    text = msg.text ?: "",
                    style = TextStyle(
                        fontFamily = Geist,
                        fontWeight = FontWeight.W400,
                        fontSize = 14.sp,
                        lineHeight = 20.sp,
                        color = fg,
                    ),
                )
                MsgKind.FILE -> {
                    val fileFg = if (isOut && !mesh.isDark) Color(0xFFE8E3D6) else fg
                    val fileFg2 = if (isOut && !mesh.isDark) Color(0xCCE8E3D6) else mesh.textSecondary
                    FileChip(
                        name = msg.fileName ?: "",
                        size = msg.fileSize ?: "",
                        ext = msg.fileExt ?: "",
                        progress = msg.progress,
                        onSurface = fileFg,
                        onSurfaceSecondary = fileFg2,
                    )
                }
                MsgKind.IMAGE -> {
                    Photo(sizeDp = 220.dp, hueDeg = 38, corner = 12.dp)
                }
            }
        }
        // 时间戳行
        Row(
            modifier = Modifier.padding(top = 4.dp, start = 4.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = msg.time,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = mesh.textTertiary,
                ),
            )
            if (isOut) {
                val (label, color) = when (msg.state) {
                    MsgState.DELIVERED -> "· 已送达" to LimeDeep
                    MsgState.SENT -> "· 发送中" to mesh.flame
                    MsgState.FAILED -> "· 失败" to mesh.danger
                }
                Text(
                    text = label,
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 10.sp, color = color,
                    ),
                )
            }
        }
    }
}
