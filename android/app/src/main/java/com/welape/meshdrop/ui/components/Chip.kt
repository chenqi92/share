package com.welape.meshdrop.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.Paper

enum class ChipTone { MUTE, LIME, INK, OUTLINE, FLAME }

@Composable
fun MeshChip(
    text: String,
    tone: ChipTone = ChipTone.MUTE,
    mono: Boolean = false,
    modifier: Modifier = Modifier,
) {
    val mesh = MeshTheme.colors
    val (bg, fg, borderColor) = when (tone) {
        ChipTone.MUTE -> Triple(mesh.surface, mesh.textSecondary, Color.Transparent)
        ChipTone.LIME -> Triple(Lime, Ink, Color.Transparent)
        ChipTone.INK -> Triple(mesh.textPrimary, mesh.canvas, Color.Transparent)
        ChipTone.OUTLINE -> Triple(Color.Transparent, mesh.textSecondary, mesh.outline)
        ChipTone.FLAME -> Triple(mesh.flame, Paper, Color.Transparent)
    }
    val style = TextStyle(
        fontFamily = if (mono) GeistMono else Geist,
        fontWeight = FontWeight.W600,
        fontSize = 11.sp,
        letterSpacing = if (mono) 1.0.sp else 0.sp,
        color = fg,
    )

    Box(
        modifier = modifier
            .height(20.dp)
            .defaultMinSize(minWidth = 24.dp)
            .clip(RoundedCornerShape(999.dp))
            .let { if (borderColor != Color.Transparent) it.border(1.dp, borderColor, RoundedCornerShape(999.dp)) else it }
            .background(bg)
            .padding(PaddingValues(horizontal = 8.dp, vertical = 0.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Text(text = text, style = style)
    }
}
