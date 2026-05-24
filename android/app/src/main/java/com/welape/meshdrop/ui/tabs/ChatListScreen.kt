package com.welape.meshdrop.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
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
import com.welape.meshdrop.mock.MockChatPreview
import com.welape.meshdrop.mock.MockChatPreviews
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.mock.MockDeviceById
import com.welape.meshdrop.mock.MockDevices
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.MeshAvatar
import com.welape.meshdrop.ui.components.MeshIconBtn
import com.welape.meshdrop.ui.components.OnlineDot
import com.welape.meshdrop.ui.theme.Flame
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@Composable
fun ChatListScreen(
    onOpenChat: (String) -> Unit,
    previews: List<MockChatPreview> = MockChatPreviews,
    devices: List<MockDevice> = MockDevices,
) {
    val mesh = MeshTheme.colors
    val byId = devices.associateBy { it.id }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(mesh.canvas)
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(horizontal = 20.dp)),
    ) {
        Spacer(Modifier.height(20.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column {
                Text(
                    text = "聊天 · Chats",
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 28.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
                    ),
                )
                Text(
                    text = "${previews.size} 个会话 · 端到端加密",
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = mesh.textTertiary,
                    ),
                )
            }
            Spacer(Modifier.weight(1f))
            MeshIconBtn(icon = Icons.Outlined.Search, contentDescription = "搜索", bordered = true, sizeDp = 36.dp)
        }

        Spacer(Modifier.height(8.dp))
        AsciiDivider(label = "今天 · TODAY · ${previews.size}")

        if (previews.isEmpty()) {
            Spacer(Modifier.height(20.dp))
            Text(
                text = "还没有会话 · No conversations yet",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 12.sp, color = mesh.textTertiary,
                ),
            )
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                previews.forEach { prev ->
                    ChatListRow(
                        device = byId[prev.deviceId] ?: MockDeviceById(prev.deviceId),
                        snippet = prev.lastSnippet,
                        time = prev.lastTime,
                        unread = prev.unread,
                        isFile = prev.isFile,
                        onClick = { onOpenChat(prev.deviceId) },
                    )
                }
            }
        }
        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun ChatListRow(
    device: MockDevice?,
    snippet: String,
    time: String,
    unread: Int,
    isFile: Boolean,
    onClick: () -> Unit,
) {
    val mesh = MeshTheme.colors
    device ?: return
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, mesh.outline, RoundedCornerShape(14.dp))
            .background(mesh.card)
            .clickable(onClick = onClick)
            .padding(PaddingValues(horizontal = 12.dp, vertical = 12.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(contentAlignment = Alignment.BottomEnd) {
            MeshAvatar(initials = device.initials, color = device.color, sizeDp = 40)
            if (device.online) {
                Box(Modifier.size(12.dp)) { OnlineDot(sizeDp = 10) }
            }
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = device.who,
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W700,
                        fontSize = 15.sp, color = mesh.textPrimary,
                    ),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = device.name,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 10.sp, color = mesh.textTertiary,
                    ),
                )
            }
            Spacer(Modifier.height(2.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (isFile) {
                    Text(
                        text = "FILE  ",
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W700,
                            fontSize = 10.sp, letterSpacing = 1.4.sp, color = mesh.flame,
                        ),
                    )
                }
                Text(
                    text = snippet,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W400,
                        fontSize = 13.sp, color = mesh.textSecondary,
                    ),
                )
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = time,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = mesh.textTertiary,
                ),
            )
            Spacer(Modifier.height(4.dp))
            if (unread > 0) {
                Box(
                    Modifier
                        .size(20.dp)
                        .clip(CircleShape)
                        .background(Lime),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = unread.toString(),
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W700,
                            fontSize = 10.sp, color = Ink,
                        ),
                    )
                }
            }
        }
    }
}
