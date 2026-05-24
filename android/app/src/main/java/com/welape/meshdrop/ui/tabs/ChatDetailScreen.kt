package com.welape.meshdrop.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Send
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
import com.welape.meshdrop.mock.MockChatWithMengxi
import com.welape.meshdrop.mock.MockDeviceById
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.MeshAvatar
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.MeshIconBtn
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.components.MsgBubble
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@Composable
fun ChatDetailScreen(
    deviceId: String,
    onBack: (() -> Unit)?,
    showDropOverlay: Boolean = false,
) {
    val mesh = MeshTheme.colors
    val device = MockDeviceById(deviceId) ?: return
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(mesh.canvas),
    ) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(mesh.surface)
                .padding(PaddingValues(horizontal = 16.dp, vertical = 12.dp)),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            if (onBack != null) {
                MeshIconBtn(icon = Icons.Outlined.ArrowBack, contentDescription = "返回", bordered = true, sizeDp = 36.dp, onClick = onBack)
            }
            MeshAvatar(initials = device.initials, color = device.color, sizeDp = 36)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    device.who,
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 16.sp, color = mesh.textPrimary,
                    ),
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Box(
                        Modifier
                            .size(6.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(Lime),
                    )
                    Text(
                        text = "${device.os} · ${device.rttMs} ms · ${device.ip}",
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W500,
                            fontSize = 10.sp, color = mesh.textTertiary,
                        ),
                    )
                }
            }
            MeshChip(text = "E2E", tone = ChipTone.LIME, mono = true)
            MeshIconBtn(icon = Icons.Outlined.MoreHoriz, contentDescription = "更多", bordered = true, sizeDp = 36.dp)
        }

        Box(modifier = Modifier.weight(1f)) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { AsciiDivider(label = "今天 · 14:00 · TODAY") }
                items(MockChatWithMengxi) { msg ->
                    MsgBubble(msg = msg)
                }
            }
            if (showDropOverlay) DropOverlay(peerName = device.who)
        }

        // Composer
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(mesh.surface)
                .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp)),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            MeshIconBtn(icon = Icons.Outlined.Add, contentDescription = "附加", accent = true, sizeDp = 40.dp)
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(RoundedCornerShape(20.dp))
                    .background(mesh.card)
                    .border(1.dp, mesh.outline, RoundedCornerShape(20.dp))
                    .padding(PaddingValues(horizontal = 14.dp, vertical = 10.dp)),
                contentAlignment = Alignment.CenterStart,
            ) {
                Text(
                    text = "发条消息给 ${device.who}…",
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W400,
                        fontSize = 13.sp, color = mesh.textTertiary,
                    ),
                )
            }
            MeshIconBtn(icon = Icons.Outlined.AttachFile, contentDescription = "文件", bordered = true, sizeDp = 40.dp)
            MeshIconBtn(icon = Icons.Outlined.Send, contentDescription = "发送", accent = true, sizeDp = 40.dp)
        }
    }
}

@Composable
private fun DropOverlay(peerName: String) {
    val mesh = MeshTheme.colors
    Box(
        Modifier
            .fillMaxSize()
            .padding(20.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Lime.copy(alpha = 0.32f))
            .border(
                width = 2.dp, color = Ink,
                shape = RoundedCornerShape(20.dp),
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            MonoLabel(label = "DROP TO SEND")
            Spacer(Modifier.height(8.dp))
            Text(
                text = "放手即发 · 3 个文件 · 12.4 MB",
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 18.sp, color = Ink,
                ),
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = "→ $peerName",
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 26.sp, color = Ink, letterSpacing = (-0.4).sp,
                ),
            )
        }
    }
}
