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
import androidx.compose.material.icons.outlined.Notes
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
) {
    val mesh = MeshTheme.colors
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
                "发送 · Send",
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 22.sp, color = mesh.textPrimary, letterSpacing = (-0.4).sp,
                ),
            )
            Text(
                "选一种内容，再选目标设备",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 11.sp, color = mesh.textTertiary,
                ),
            )

            AsciiDivider(label = "内容类型 · KIND")

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.Outlined.Image, label = "图片", subtitle = "相册 / 截屏", onClick = onPickDevices)
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.Outlined.PhotoLibrary, label = "多图", subtitle = "批量发送", onClick = onPickDevices)
            }
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.Outlined.AttachFile, label = "文件", subtitle = "本机存储", onClick = onPickDevices)
                QuickActionTile(modifier = Modifier.weight(1f), icon = Icons.Outlined.Notes, label = "文字便签", subtitle = "粘贴 / 写一段", onClick = onPickDevices, accent = true)
            }

            Spacer(Modifier.height(18.dp))
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(Lime)
                    .clickable { onPickDevices() }
                    .padding(PaddingValues(horizontal = 16.dp, vertical = 16.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "选择目标设备 →",
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
