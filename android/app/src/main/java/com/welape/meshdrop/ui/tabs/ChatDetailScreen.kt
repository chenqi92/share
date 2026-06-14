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
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Send
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.res.stringResource
import com.welape.meshdrop.R
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockChatWithMengxi
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.mock.MockDeviceById
import com.welape.meshdrop.mock.MockMessage
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
    device: MockDevice? = null,
    messages: List<MockMessage>? = null,
    useMockFallback: Boolean = true,
    onSendText: (String) -> Unit = {},
    onAttachFile: () -> Unit = {},
) {
    val mesh = MeshTheme.colors
    val displayDevice = device ?: if (useMockFallback) MockDeviceById(deviceId) else null
    val displayMessages = messages ?: if (useMockFallback) MockChatWithMengxi else emptyList()
    var draft by remember(deviceId) { mutableStateOf("") }
    fun sendDraft() {
        val text = draft.trim()
        if (text.isEmpty()) return
        onSendText(text)
        draft = ""
    }
    if (displayDevice == null) return
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
                MeshIconBtn(icon = Icons.Outlined.ArrowBack, contentDescription = stringResource(R.string.common_back), bordered = true, sizeDp = 36.dp, onClick = onBack)
            }
            MeshAvatar(initials = displayDevice.initials, color = displayDevice.color, sizeDp = 36)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    displayDevice.who,
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
                        text = "${displayDevice.os} · ${displayDevice.rttMs} ms · ${displayDevice.ip}",
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W500,
                            fontSize = 10.sp, color = mesh.textTertiary,
                        ),
                    )
                }
            }
            MeshChip(text = "LAN", tone = ChipTone.OUTLINE, mono = true)
            MeshIconBtn(icon = Icons.Outlined.MoreHoriz, contentDescription = stringResource(R.string.common_more), bordered = true, sizeDp = 36.dp)
        }

        Box(modifier = Modifier.weight(1f)) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                contentPadding = PaddingValues(top = 8.dp, bottom = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { AsciiDivider(label = stringResource(R.string.chat_detail_section_today)) }
                items(displayMessages, key = { it.id }) { msg ->
                    MsgBubble(msg = msg)
                }
            }
            if (showDropOverlay) DropOverlay(peerName = displayDevice.who)
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
            MeshIconBtn(icon = Icons.Outlined.Add, contentDescription = stringResource(R.string.common_attach), accent = true, sizeDp = 40.dp, onClick = onAttachFile)
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
                BasicTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    singleLine = true,
                    textStyle = TextStyle(
                        fontFamily = Geist,
                        fontWeight = FontWeight.W400,
                        fontSize = 13.sp,
                        color = mesh.textPrimary,
                    ),
                    cursorBrush = SolidColor(mesh.textPrimary),
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { sendDraft() }),
                    modifier = Modifier.fillMaxWidth(),
                    decorationBox = { innerTextField ->
                        if (draft.isBlank()) {
                            Text(
                                text = stringResource(R.string.chat_composer_placeholder, displayDevice.who),
                                style = TextStyle(
                                    fontFamily = Geist, fontWeight = FontWeight.W400,
                                    fontSize = 13.sp, color = mesh.textTertiary,
                                ),
                            )
                        }
                        innerTextField()
                    },
                )
            }
            MeshIconBtn(icon = Icons.Outlined.AttachFile, contentDescription = stringResource(R.string.common_file), bordered = true, sizeDp = 40.dp, onClick = onAttachFile)
            MeshIconBtn(icon = Icons.Outlined.Send, contentDescription = stringResource(R.string.common_send), accent = true, sizeDp = 40.dp, onClick = { sendDraft() })
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
            MonoLabel(label = stringResource(R.string.chat_drop_label))
            Spacer(Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.chat_drop_summary),
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
