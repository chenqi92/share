package com.welape.meshdrop.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme

@Composable
fun MeshIconBtn(
    icon: ImageVector,
    contentDescription: String?,
    sizeDp: Dp = 32.dp,
    accent: Boolean = false,
    circle: Boolean = true,
    bordered: Boolean = false,
    tint: Color? = null,
    onClick: () -> Unit,
) {
    val mesh = MeshTheme.colors
    val bg = when {
        accent -> Lime
        bordered -> Color.Transparent
        else -> mesh.surface
    }
    val fg = tint ?: if (accent) Ink else mesh.textPrimary
    val shape = if (circle) CircleShape else RoundedCornerShape(10.dp)
    val mod = Modifier
        .size(sizeDp)
        .clip(shape)
        .let { if (bordered) it.border(1.dp, mesh.outline, shape) else it }
        .background(bg)
        .clickable(onClick = onClick)
    Box(modifier = mod, contentAlignment = Alignment.Center) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            tint = fg,
            modifier = Modifier.size(sizeDp * 0.5f),
        )
    }
}
