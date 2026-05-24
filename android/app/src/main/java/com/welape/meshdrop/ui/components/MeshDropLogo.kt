package com.welape.meshdrop.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

/** 重叠两圆环 + 中间 lime 实心点。viewBox 24×24，stroke 2。 */
@Composable
fun MeshDropMark(
    size: androidx.compose.ui.unit.Dp = 24.dp,
    strokeColor: Color = MeshTheme.colors.textPrimary,
    dotColor: Color = Lime,
) {
    Canvas(modifier = Modifier.size(size)) {
        val w = this.size.width
        val h = this.size.height
        val r = w * (6.5f / 24f)
        val strokePx = w * (2f / 24f)
        val cy = h / 2f
        val cxLeft = w * (9f / 24f)
        val cxRight = w * (15f / 24f)
        drawCircle(
            color = strokeColor,
            radius = r,
            center = Offset(cxLeft, cy),
            style = Stroke(width = strokePx),
        )
        drawCircle(
            color = strokeColor,
            radius = r,
            center = Offset(cxRight, cy),
            style = Stroke(width = strokePx),
        )
        // lime 实心圆点：r=1.8 在 viewBox 24×24
        drawCircle(
            color = dotColor,
            radius = w * (1.8f / 24f),
            center = Offset(w / 2f, cy),
        )
    }
}

/** "meshdrop" wordmark + 末尾 lime 圆点。点不能省。 */
@Composable
fun MeshDropWordmark(
    fontSize: androidx.compose.ui.unit.TextUnit = 22.sp,
    color: Color = MeshTheme.colors.textPrimary,
    dotColor: Color = Lime,
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = "meshdrop",
            style = TextStyle(
                fontFamily = SpaceGrotesk,
                fontWeight = FontWeight.W700,
                fontSize = fontSize,
                letterSpacing = (-0.5).sp,
                color = color,
            ),
        )
        Spacer(Modifier.width(3.dp))
        // 末尾 lime 圆点
        Canvas(modifier = Modifier.size(fontSize.value.dp * 0.30f)) {
            drawCircle(color = dotColor)
        }
    }
}

/** logo + wordmark 横排锁定组合。 */
@Composable
fun MeshDropLockup(
    markSize: androidx.compose.ui.unit.Dp = 28.dp,
    fontSize: androidx.compose.ui.unit.TextUnit = 22.sp,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        MeshDropMark(size = markSize)
        MeshDropWordmark(fontSize = fontSize)
    }
}
