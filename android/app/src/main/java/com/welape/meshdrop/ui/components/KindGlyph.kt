package com.welape.meshdrop.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.welape.meshdrop.mock.DeviceKind
import com.welape.meshdrop.ui.theme.MeshTheme

/** 每 OS 一个小线条 glyph。size 10-12，用于设备 row 副标题前置。 */
@Composable
fun KindGlyph(
    kind: DeviceKind,
    sizeDp: Dp = 12.dp,
    color: Color = MeshTheme.colors.textSecondary,
) {
    Canvas(modifier = Modifier.size(sizeDp)) {
        val w = size.width
        val h = size.height
        val s = w * (1.2f / 12f)
        val stroke = Stroke(width = s)
        when (kind) {
            DeviceKind.MAC -> {
                drawRect(
                    color = color,
                    topLeft = Offset(0f, h * 0.10f),
                    size = Size(w, h * 0.62f),
                    style = stroke,
                )
                drawLine(color, Offset(w * 0.30f, h * 0.92f), Offset(w * 0.70f, h * 0.92f), strokeWidth = s)
            }
            DeviceKind.WIN -> {
                drawLine(color, Offset(0f, h / 2), Offset(w, h / 2), strokeWidth = s)
                drawLine(color, Offset(w / 2, 0f), Offset(w / 2, h), strokeWidth = s)
                drawRect(color = color, topLeft = Offset.Zero, size = Size(w, h), style = stroke)
            }
            DeviceKind.IPAD -> {
                drawRoundRect(
                    color = color,
                    topLeft = Offset(w * 0.10f, h * 0.05f),
                    size = Size(w * 0.80f, h * 0.90f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.10f),
                    style = stroke,
                )
                drawCircle(color = color, radius = w * 0.05f, center = Offset(w / 2f, h * 0.85f))
            }
            DeviceKind.IPHONE, DeviceKind.ANDROID -> {
                drawRoundRect(
                    color = color,
                    topLeft = Offset(w * 0.22f, h * 0.05f),
                    size = Size(w * 0.56f, h * 0.90f),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.14f),
                    style = stroke,
                )
                drawLine(color, Offset(w * 0.36f, h * 0.85f), Offset(w * 0.64f, h * 0.85f), strokeWidth = s)
            }
            DeviceKind.LINUX -> {
                drawCircle(color = color, radius = w * 0.34f, center = Offset(w / 2f, h / 2f), style = stroke)
                drawLine(color, Offset(w * 0.50f, h * 0.20f), Offset(w * 0.50f, h * 0.60f), strokeWidth = s)
            }
        }
    }
}
