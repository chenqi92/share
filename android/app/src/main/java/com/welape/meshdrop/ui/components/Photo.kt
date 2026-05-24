package com.welape.meshdrop.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** 渐变背景 + 地平线 + 假太阳 + 山形 placeholder。 */
@Composable
fun Photo(
    sizeDp: Dp = 96.dp,
    hueDeg: Int = 16,
    corner: Dp = 14.dp,
    modifier: Modifier = Modifier,
) {
    val (skyTop, skyBot, sun, mountain) = palette(hueDeg)
    Box(
        modifier = modifier
            .size(sizeDp)
            .clip(RoundedCornerShape(corner)),
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawRect(brush = Brush.verticalGradient(listOf(skyTop, skyBot)))
            // 太阳
            drawCircle(color = sun, radius = size.minDimension * 0.16f,
                center = Offset(size.width * 0.70f, size.height * 0.32f))
            // 地平线
            val horizonY = size.height * 0.62f
            drawLine(Color(0x33000000), Offset(0f, horizonY), Offset(size.width, horizonY), strokeWidth = 1f)
            // 远山
            val mountainPath = Path().apply {
                moveTo(0f, horizonY)
                lineTo(size.width * 0.20f, horizonY - size.height * 0.18f)
                lineTo(size.width * 0.40f, horizonY - size.height * 0.06f)
                lineTo(size.width * 0.62f, horizonY - size.height * 0.22f)
                lineTo(size.width * 0.85f, horizonY - size.height * 0.04f)
                lineTo(size.width, horizonY - size.height * 0.12f)
                lineTo(size.width, size.height)
                lineTo(0f, size.height)
                close()
            }
            drawPath(mountainPath, color = mountain)
        }
    }
}

private fun palette(hue: Int): List<Color> {
    // hue 0..360 简单环色
    val base = (hue % 360 + 360) % 360
    fun hsl(h: Int, s: Float, l: Float, a: Float = 1f): Color {
        val c = (1 - kotlin.math.abs(2 * l - 1)) * s
        val hp = h / 60f
        val x = c * (1 - kotlin.math.abs(hp % 2 - 1))
        val (r, g, b) = when (hp.toInt()) {
            0 -> Triple(c, x, 0f); 1 -> Triple(x, c, 0f); 2 -> Triple(0f, c, x)
            3 -> Triple(0f, x, c); 4 -> Triple(x, 0f, c); else -> Triple(c, 0f, x)
        }
        val m = l - c / 2
        return Color(r + m, g + m, b + m, a)
    }
    return listOf(
        hsl(base, 0.32f, 0.78f),                         // skyTop
        hsl((base + 30) % 360, 0.40f, 0.62f),            // skyBottom
        hsl((base + 28) % 360, 0.95f, 0.58f),            // sun
        hsl((base + 220) % 360, 0.20f, 0.18f),           // mountain
    )
}
