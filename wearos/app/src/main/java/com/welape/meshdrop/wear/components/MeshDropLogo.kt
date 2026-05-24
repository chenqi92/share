package com.welape.meshdrop.wear.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.welape.meshdrop.wear.ui.theme.MDColor

@Composable
fun MeshDropMark(sizeDp: Int = 14) {
    Canvas(modifier = Modifier.size(sizeDp.dp)) {
        val w = size.width
        val h = size.height
        val ringR = w * (6.5f / 24f)
        val strokeW = w * (2f / 24f)
        // 左圈
        drawCircle(
            color = MDColor.dpaper,
            radius = ringR,
            center = Offset(w * (9f / 24f), h * 0.5f),
            style = Stroke(width = strokeW),
        )
        // 右圈
        drawCircle(
            color = MDColor.dpaper,
            radius = ringR,
            center = Offset(w * (15f / 24f), h * 0.5f),
            style = Stroke(width = strokeW),
        )
        // 中间 lime 实心圆点
        drawCircle(
            color = MDColor.lime,
            radius = w * (1.8f / 24f),
            center = Offset(w / 2f, h / 2f),
        )
    }
}
