package com.welape.meshdrop.wear.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.welape.meshdrop.wear.components.Avatar
import com.welape.meshdrop.wear.components.MeshDropMark
import com.welape.meshdrop.wear.mock.Mock
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

@Composable
fun NearbyScreen(
    onPick: (String) -> Unit = {},
    onOpenReceive: () -> Unit = {},
) {
    val devices = Mock.devices
    var focusIndex by remember { mutableIntStateOf(0) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink),
        contentAlignment = Alignment.Center,
    ) {
        // 背景：同心圆 + 扫描臂的视觉静态版本
        RadarBackdrop()

        // 顶部 logo
        Row(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 22.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            MeshDropMark(sizeDp = 12)
            Text(
                text = "meshdrop",
                color = MDColor.dpaper,
                style = MDType.body(10f, FontWeight.SemiBold),
            )
            Box(
                modifier = Modifier
                    .size(3.dp)
                    .background(MDColor.lime, CircleShape),
            )
        }

        // 中心数字 5 + NEARBY
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = "${devices.size}",
                color = MDColor.dpaper,
                style = MDType.display(46f, FontWeight.Bold),
            )
            Spacer(modifier = Modifier.height(2.dp))
            Box(
                modifier = Modifier
                    .background(MDColor.dink3, RoundedCornerShape(999.dp))
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            ) {
                Text(
                    text = "NEARBY",
                    color = MDColor.lime,
                    style = MDType.mono(10f, FontWeight.Bold, tracking = 2.0f),
                )
            }
        }

        // 5 个 avatar 沿圆环放置
        val density = LocalDensity.current
        val minRadiusDp = 46f
        val maxRadiusDp = 76f
        Box(modifier = Modifier.fillMaxSize()) {
            devices.forEachIndexed { idx, d ->
                val angleRad = Math.toRadians(d.angleDeg.toDouble() - 90.0)
                val r = minRadiusDp + (maxRadiusDp - minRadiusDp) * d.dist
                val radiusPx = with(density) { r.dp.toPx() }
                val dx = (radiusPx * cos(angleRad)).toFloat()
                val dy = (radiusPx * sin(angleRad)).toFloat()
                Box(
                    modifier = Modifier
                        .fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        modifier = Modifier.offset { IntOffset(dx.roundToInt(), dy.roundToInt()) },
                    ) {
                        Avatar(
                            initials = d.initials,
                            color = d.color,
                            sizeDp = if (idx == focusIndex) 28 else 24,
                            ring = idx == focusIndex,
                            ringColor = MDColor.lime,
                        )
                    }
                }
            }
        }

        // 底部 hint（单行，避免和南向 avatar 冲突）
        Text(
            text = "转表冠选 · 按发",
            color = MDColor.muted,
            style = MDType.mono(10f, FontWeight.Medium, tracking = 1.2f),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 22.dp),
        )
    }
}

@Composable
private fun RadarBackdrop() {
    Canvas(modifier = Modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val cx = w / 2f
        val cy = h / 2f
        val maxR = (minOf(w, h) / 2f) - 4f
        // 同心圆 3 环（faint）
        for (i in 1..3) {
            drawCircle(
                color = MDColor.lime.copy(alpha = 0.07f),
                radius = maxR * (i / 3f),
                center = Offset(cx, cy),
                style = Stroke(width = 0.8f),
            )
        }
        // 扫描臂残影（一个扇形 lime 透明渐变 - 用一条粗线模拟）
        val sweepAngleDeg = 22.0
        val angleRad = Math.toRadians(-65.0) // 静态截图就放在 65°方位
        val ex = cx + (maxR * cos(angleRad)).toFloat()
        val ey = cy + (maxR * sin(angleRad)).toFloat()
        drawLine(
            color = MDColor.lime.copy(alpha = 0.22f),
            start = Offset(cx, cy),
            end = Offset(ex, ey),
            strokeWidth = 6f,
        )
        // 十字线（faint）
        drawLine(MDColor.dline, Offset(cx, 6f), Offset(cx, h - 6f), strokeWidth = 0.6f)
        drawLine(MDColor.dline, Offset(6f, cy), Offset(w - 6f, cy), strokeWidth = 0.6f)
    }
}
