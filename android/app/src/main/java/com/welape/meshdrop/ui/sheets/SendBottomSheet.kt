package com.welape.meshdrop.ui.sheets

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AttachFile
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.automirrored.outlined.Notes
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.R
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SendBottomSheet(
    onDismiss: () -> Unit,
    onPickDevices: () -> Unit,
    onSendTextDraft: (String) -> Unit = {},
) {
    val mesh = MeshTheme.colors
    var draft by remember { mutableStateOf("") }
    val sheetState = rememberModalBottomSheetState()
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = mesh.card,
        contentColor = mesh.textPrimary,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(PaddingValues(horizontal = 22.dp, vertical = 12.dp)),
        ) {
            Text(
                stringResource(R.string.send_title),
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 22.sp, color = mesh.textPrimary, letterSpacing = (-0.4).sp,
                ),
            )
            Text(
                stringResource(R.string.send_subtitle),
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 11.sp, color = mesh.textTertiary,
                ),
            )

            AsciiDivider(label = stringResource(R.string.send_section_kind))

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.Outlined.Image, label = stringResource(R.string.send_kind_image), subtitle = stringResource(R.string.send_kind_image_sub), onClick = onPickDevices)
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.Outlined.PhotoLibrary, label = stringResource(R.string.send_kind_multi), subtitle = stringResource(R.string.send_kind_multi_sub), onClick = onPickDevices)
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.Outlined.AttachFile, label = stringResource(R.string.send_kind_file), subtitle = stringResource(R.string.send_kind_file_sub), onClick = onPickDevices)
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.AutoMirrored.Outlined.Notes, label = stringResource(R.string.send_kind_note), subtitle = stringResource(R.string.send_kind_note_sub), onClick = onPickDevices, accent = true)
            }

            Spacer(Modifier.height(14.dp))
            AsciiDivider(label = stringResource(R.string.send_section_note))
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(mesh.surface)
                    .padding(PaddingValues(horizontal = 12.dp, vertical = 12.dp)),
            ) {
                BasicTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    textStyle = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W500,
                        fontSize = 14.sp, color = mesh.textPrimary,
                    ),
                    cursorBrush = SolidColor(mesh.textPrimary),
                    modifier = Modifier.fillMaxWidth(),
                    decorationBox = { inner ->
                        if (draft.isEmpty()) {
                            Text(
                                stringResource(R.string.send_note_placeholder),
                                style = TextStyle(
                                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                                    fontSize = 12.sp, color = mesh.textTertiary,
                                ),
                            )
                        }
                        inner()
                    },
                )
            }

            Spacer(Modifier.height(14.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Lime)
                    .clickable {
                        if (draft.isNotBlank()) onSendTextDraft(draft.trim())
                        onPickDevices()
                    }
                    .padding(PaddingValues(horizontal = 16.dp, vertical = 16.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    if (draft.isBlank()) stringResource(R.string.send_pick_target) else stringResource(R.string.send_pick_target_with_note),
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 16.sp, color = Ink,
                    ),
                )
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun QuickActionTile(
    icon: ImageVector,
    label: String,
    subtitle: String,
    onClick: () -> Unit,
    accent: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val mesh = MeshTheme.colors
    val bg = if (accent) Lime else mesh.surface
    val fg = if (accent) Ink else mesh.textPrimary
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .let { if (!accent) it.border(1.dp, mesh.outline, RoundedCornerShape(14.dp)) else it }
            .clickable(onClick = onClick)
            .padding(PaddingValues(horizontal = 14.dp, vertical = 14.dp)),
    ) {
        Icon(imageVector = icon, contentDescription = label, tint = fg, modifier = Modifier.size(22.dp))
        Spacer(Modifier.height(10.dp))
        Text(
            label,
            style = TextStyle(
                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                fontSize = 16.sp, color = fg,
            ),
        )
        Text(
            subtitle,
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                fontSize = 10.sp, color = if (accent) Ink.copy(alpha = 0.65f) else mesh.textTertiary,
            ),
        )
    }
}
