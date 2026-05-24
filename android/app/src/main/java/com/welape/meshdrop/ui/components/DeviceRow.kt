package com.welape.meshdrop.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme

/**
 * 卡片样的设备 row。
 * 自带 selected / multiSelect / pickerSelected 状态视觉。
 */
@Composable
fun DeviceRow(
    device: MockDevice,
    selected: Boolean = false,
    pickerSelected: Boolean = false,
    showOnlineDot: Boolean = true,
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {},
    onLongClick: (() -> Unit)? = null,
) {
    val mesh = MeshTheme.colors
    val bg = when {
        pickerSelected -> mesh.limeFill
        selected -> mesh.limeFill
        else -> mesh.card
    }
    val borderColor = when {
        pickerSelected -> Lime
        selected -> Lime
        else -> mesh.outline
    }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, borderColor, RoundedCornerShape(14.dp))
            .background(bg)
            .let { mod ->
                if (onLongClick != null) {
                    // 长按由父层用 combinedClickable 包装也行；这里用普通 click。
                    mod.clickable(onClick = onClick)
                } else {
                    mod.clickable(onClick = onClick)
                }
            }
            .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(contentAlignment = Alignment.BottomEnd) {
            MeshAvatar(initials = device.initials, color = device.color, sizeDp = 36)
            if (showOnlineDot && device.online) {
                Box(Modifier.size(12.dp), contentAlignment = Alignment.Center) {
                    OnlineDot(sizeDp = 10)
                }
            }
        }
        Box(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = device.name,
                style = TextStyle(
                    fontFamily = Geist,
                    fontWeight = FontWeight.W600,
                    fontSize = 14.sp,
                    color = mesh.textPrimary,
                ),
            )
            Row(
                modifier = Modifier.padding(top = 3.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                KindGlyph(kind = device.kind, sizeDp = 11.dp, color = mesh.textTertiary)
                Text(
                    text = "${device.os} · ${device.rttMs} ms",
                    style = TextStyle(
                        fontFamily = GeistMono,
                        fontWeight = FontWeight.W500,
                        fontSize = 11.sp,
                        color = mesh.textTertiary,
                    ),
                )
            }
        }
        if (pickerSelected) {
            Box(
                Modifier
                    .size(22.dp)
                    .clip(RoundedCornerShape(11.dp))
                    .background(Lime),
                contentAlignment = Alignment.Center,
            ) {
                Text("✓", style = TextStyle(color = Color.Black, fontSize = 13.sp, fontWeight = FontWeight.W700))
            }
        }
    }
}
