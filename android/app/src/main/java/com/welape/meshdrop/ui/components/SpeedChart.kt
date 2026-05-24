package com.welape.meshdrop.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.welape.meshdrop.ui.theme.Flame
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.Sky

/** 上行 / 下行双系列柱状图（堆叠并列）。 */
@Composable
fun SpeedChart(
    upBars: List<Int>,
    downBars: List<Int>,
    height: Dp = 96.dp,
    upColor: Color = Flame,
    downColor: Color = Sky,
) {
    val mesh = MeshTheme.colors
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height),
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val n = maxOf(upBars.size, downBars.size)
            if (n == 0) return@Canvas
            val maxV = (upBars + downBars).maxOrNull()?.toFloat() ?: 1f
            val barGroupW = size.width / n
            val barW = (barGroupW * 0.32f).coerceAtLeast(2f)
            for (i in 0 until n) {
                val up = (upBars.getOrNull(i) ?: 0).toFloat()
                val down = (downBars.getOrNull(i) ?: 0).toFloat()
                val xCenter = barGroupW * (i + 0.5f)
                val upH = (up / maxV) * size.height * 0.85f
                val downH = (down / maxV) * size.height * 0.85f
                // 上行（上半）
                drawRoundRect(
                    color = upColor,
                    topLeft = Offset(xCenter - barW - 1f, size.height / 2f - upH),
                    size = Size(barW, upH),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(2f, 2f),
                )
                // 下行（下半，镜像）
                drawRoundRect(
                    color = downColor,
                    topLeft = Offset(xCenter + 1f, size.height / 2f),
                    size = Size(barW, downH),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(2f, 2f),
                )
            }
            // 中线
            drawLine(
                color = mesh.outline,
                start = Offset(0f, size.height / 2f),
                end = Offset(size.width, size.height / 2f),
                strokeWidth = 1f,
            )
        }
    }
}

/** 单系列柱状（session 总量）。 */
@Composable
fun SessionBars(
    bars: List<Int>,
    height: Dp = 56.dp,
    color: Color = MeshTheme.colors.lime,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(height),
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            if (bars.isEmpty()) return@Canvas
            val maxV = bars.max().toFloat()
            val groupW = size.width / bars.size
            val barW = (groupW * 0.55f).coerceAtLeast(3f)
            bars.forEachIndexed { i, v ->
                val h = (v / maxV) * size.height
                val x = groupW * (i + 0.5f) - barW / 2
                drawRoundRect(
                    color = color,
                    topLeft = Offset(x, size.height - h),
                    size = Size(barW, h),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(2f, 2f),
                )
            }
        }
    }
}
