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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowDropDown
import androidx.compose.material.icons.outlined.ContentCopy
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.res.stringResource
import com.welape.meshdrop.R
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.data.ClipboardEntry
import com.welape.meshdrop.data.Device
import com.welape.meshdrop.transport.ShareEngine
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.Sky
import com.welape.meshdrop.ui.theme.SpaceGrotesk
import kotlinx.coroutines.flow.MutableStateFlow

@Composable
fun ClipboardScreen(engine: ShareEngine? = null) {
    val mesh = MeshTheme.colors
    val clipboard = LocalClipboardManager.current

    val devices by remember(engine) {
        engine?.devices ?: MutableStateFlow(emptyList())
    }.collectAsState()
    val inbox by remember(engine) {
        engine?.clipboardInbox ?: MutableStateFlow(emptyList())
    }.collectAsState()

    var selectedId by remember { mutableStateOf<String?>(null) }
    var draft by remember { mutableStateOf("") }
    var menuOpen by remember { mutableStateOf(false) }

    val target: Device? = devices.firstOrNull { it.id == selectedId } ?: devices.firstOrNull()
    val canPush = engine != null && target != null && draft.isNotBlank()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(mesh.canvas)
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(horizontal = 20.dp)),
    ) {
        Spacer(Modifier.height(20.dp))
        Column {
            Text(
                text = stringResource(R.string.clipboard_title),
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 28.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
                ),
            )
            Text(
                text = stringResource(R.string.clipboard_subtitle),
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 11.sp, color = mesh.textTertiary,
                ),
            )
        }

        Spacer(Modifier.height(16.dp))

        // ── 推送编辑器 ──
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(mesh.card)
                .border(1.dp, mesh.outline, RoundedCornerShape(18.dp))
                .padding(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = stringResource(R.string.clipboard_push_to),
                    style = TextStyle(fontFamily = GeistMono, fontSize = 11.sp, color = mesh.textTertiary),
                )
                Spacer(Modifier.width(8.dp))
                Box {
                    TextButton(onClick = { if (devices.isNotEmpty()) menuOpen = true }) {
                        Text(
                            text = target?.name ?: stringResource(R.string.clipboard_no_device),
                            style = TextStyle(fontFamily = GeistMono, fontWeight = FontWeight.W600, fontSize = 12.sp, color = mesh.textPrimary),
                        )
                        Icon(Icons.Outlined.ArrowDropDown, contentDescription = null, tint = mesh.textSecondary)
                    }
                    DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                        devices.forEach { d ->
                            DropdownMenuItem(
                                text = { Text(d.name) },
                                onClick = { selectedId = d.id; menuOpen = false },
                            )
                        }
                    }
                }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = {
                    clipboard.getText()?.text?.let { if (it.isNotEmpty()) draft = it }
                }) {
                    Icon(Icons.Outlined.ContentPaste, contentDescription = stringResource(R.string.clipboard_read_clipboard), tint = Sky, modifier = Modifier.height(16.dp))
                    Spacer(Modifier.width(4.dp))
                    Text(
                        text = stringResource(R.string.clipboard_read_clipboard),
                        style = TextStyle(fontFamily = GeistMono, fontSize = 10.sp, color = Sky),
                    )
                }
            }

            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = { Text(stringResource(R.string.clipboard_input_placeholder)) },
                modifier = Modifier.fillMaxWidth().height(110.dp),
            )

            Spacer(Modifier.height(10.dp))

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(if (canPush) mesh.lime else mesh.surface)
                        .border(1.dp, if (canPush) mesh.lime else mesh.outline, RoundedCornerShape(999.dp))
                        .clickable(enabled = canPush) {
                            val dev = target ?: return@clickable
                            val content = draft.trim()
                            if (content.isNotEmpty()) {
                                engine?.pushClipboard(dev, content, ShareEngine.clipKind(content))
                                draft = ""
                            }
                        }
                        .padding(horizontal = 18.dp, vertical = 9.dp),
                ) {
                    Text(
                        text = stringResource(R.string.clipboard_push),
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W700, fontSize = 11.sp,
                            color = if (canPush) mesh.canvas else mesh.textTertiary,
                        ),
                    )
                }
            }
        }

        // ── 收件 ──
        if (inbox.isEmpty()) {
            Spacer(Modifier.height(28.dp))
            Text(
                text = stringResource(R.string.clipboard_empty),
                style = TextStyle(fontFamily = GeistMono, fontSize = 12.sp, color = mesh.textTertiary),
                modifier = Modifier.fillMaxWidth(),
            )
        } else {
            AsciiDivider(label = stringResource(R.string.clipboard_section_received, inbox.size))
            inbox.forEach { entry ->
                ClipboardCard(entry = entry, onCopy = { clipboard.setText(AnnotatedString(entry.content)) })
                Spacer(Modifier.height(10.dp))
            }
        }

        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun ClipboardCard(entry: ClipboardEntry, onCopy: () -> Unit) {
    val mesh = MeshTheme.colors
    val tone = when (entry.kind) {
        "link" -> ChipTone.LIME
        "code" -> ChipTone.FLAME
        else -> ChipTone.OUTLINE
    }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(mesh.card)
            .border(1.dp, mesh.outline, RoundedCornerShape(18.dp))
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "↓ ${entry.peerName}",
                style = TextStyle(fontFamily = GeistMono, fontSize = 11.sp, color = Sky),
            )
            Spacer(Modifier.weight(1f))
            MeshChip(text = entry.kind.uppercase(), tone = tone, mono = true)
        }
        Spacer(Modifier.height(8.dp))
        Text(
            text = entry.content,
            style = TextStyle(
                fontFamily = if (entry.kind == "code") GeistMono else null,
                fontSize = 13.sp, color = mesh.textPrimary,
            ),
        )
        Spacer(Modifier.height(6.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            TextButton(onClick = onCopy) {
                Icon(Icons.Outlined.ContentCopy, contentDescription = stringResource(R.string.common_copy), tint = mesh.textTertiary, modifier = Modifier.height(15.dp))
                Spacer(Modifier.width(4.dp))
                Text(text = stringResource(R.string.common_copy), style = TextStyle(fontFamily = GeistMono, fontSize = 10.sp, color = mesh.textTertiary))
            }
        }
    }
}
