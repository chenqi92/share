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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.res.stringResource
import com.welape.meshdrop.R
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.DeviceKind
import com.welape.meshdrop.mock.MockChatPreview
import com.welape.meshdrop.mock.MockChatPreviews
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.mock.MockDeviceById
import com.welape.meshdrop.mock.MockDevices
import com.welape.meshdrop.ui.theme.AvatarMint
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
    allPreviews: List<MockChatPreview> = MockChatPreviews,
    devices: List<MockDevice> = MockDevices,
) {
    val mesh = MeshTheme.colors
    var searchOpen by remember { mutableStateOf(false) }
    var query by remember { mutableStateOf("") }
    val previews = remember(allPreviews, query) {
        if (query.isBlank()) allPreviews
        else allPreviews.filter { it.peerName.contains(query, true) || it.lastSnippet.contains(query, true) }
    }
    val byId = devices.associateBy { it.fingerprint }
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
                    text = stringResource(R.string.chat_title),
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 28.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
                    ),
                )
                Text(
                    text = stringResource(R.string.chat_subtitle, previews.size),
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = mesh.textTertiary,
                    ),
                )
            }
            Spacer(Modifier.weight(1f))
            MeshIconBtn(
                icon = Icons.Outlined.Search, contentDescription = stringResource(R.string.common_search),
                bordered = true, sizeDp = 36.dp,
                onClick = { searchOpen = !searchOpen; if (!searchOpen) query = "" },
            )
        }

        if (searchOpen) {
            Spacer(Modifier.height(10.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(mesh.surface)
                    .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp)),
            ) {
                BasicTextField(
                    value = query,
                    onValueChange = { query = it },
                    singleLine = true,
                    textStyle = TextStyle(fontFamily = GeistMono, fontSize = 13.sp, color = mesh.textPrimary),
                    cursorBrush = SolidColor(mesh.textPrimary),
                    modifier = Modifier.fillMaxWidth(),
                    decorationBox = { inner ->
                        if (query.isEmpty()) Text(
                            stringResource(R.string.common_search),
                            style = TextStyle(fontFamily = GeistMono, fontSize = 12.sp, color = mesh.textTertiary),
                        )
                        inner()
                    },
                )
            }
        }

        Spacer(Modifier.height(8.dp))
        AsciiDivider(label = stringResource(R.string.chat_section_today, previews.size))

        if (previews.isEmpty()) {
            Spacer(Modifier.height(20.dp))
            Text(
                text = stringResource(R.string.chat_empty),
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 12.sp, color = mesh.textTertiary,
                ),
            )
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                previews.forEach { prev ->
                    ChatListRow(
                        device = byId[prev.deviceId] ?: MockDeviceById(prev.deviceId) ?: fallbackChatDevice(prev.peerName),
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

/** 设备离线（不在已发现列表）时，用会话预览里的对端名还原一个最小展示设备，避免会话行被丢弃。 */
private fun fallbackChatDevice(name: String): MockDevice = MockDevice(
    id = "", name = name, who = name.ifBlank { "—" }, kind = DeviceKind.ANDROID,
    dist = 0f, angleDeg = 0, color = AvatarMint,
    initials = name.take(2).uppercase().ifBlank { "?" },
    os = "", rttMs = 0, online = false, ip = "—",
)

@Composable
private fun ChatListRow(
    device: MockDevice,
    snippet: String,
    time: String,
    unread: Int,
    isFile: Boolean,
    onClick: () -> Unit,
) {
    val mesh = MeshTheme.colors
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
                        text = stringResource(R.string.chat_badge_file),
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
