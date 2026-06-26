package com.welape.meshdrop.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.offset as layoutOffset
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.ui.theme.Flame
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk
import kotlin.math.cos
import kotlin.math.sin

enum class RadarVariant { SWEEP, PULSE }

/**
 * Discovery 雷达。中心 60×60 黑圆 + YOU label + 同心圆 3 环 + 设备点。
 * 默认 SWEEP 变体 4.5s/圈，含十字 + N/E/S/W。selected 时点改 flame + 拉一条 flame 虚线到中心。
 */
@Composable
fun Radar(
    devices: List<MockDevice>,
    selectedId: String? = null,
    variant: RadarVariant = RadarVariant.SWEEP,
    sizeDp: Dp = 300.dp,
    myIp: String = "192.168.1.42",
    onSelect: (String) -> Unit = {},
) {
    val mesh = MeshTheme.colors
    val ringColor = mesh.outline
    val limeArm = Lime.copy(alpha = 0.55f)

    val transition = rememberInfiniteTransition(label = "radar")
    val sweepAngle by transition.animateFloat(
        initialValue = 0f, targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 4500, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "sweep",
    )
    val pulsePhase by transition.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2400, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "pulse",
    )

    Box(modifier = Modifier.size(sizeDp), contentAlignment = Alignment.Center) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val r = size.minDimension / 2f
            val cx = size.width / 2f
            val cy = size.height / 2f

            // 3 环
            listOf(0.33f, 0.66f, 1.0f).forEach { f ->
                drawCircle(color = ringColor, radius = r * f, center = Offset(cx, cy), style = Stroke(width = 1f))
            }
            // 罗盘 / 十字
            drawLine(color = ringColor, start = Offset(cx, cy - r), end = Offset(cx, cy + r), strokeWidth = 1f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 6f)))
            drawLine(color = ringColor, start = Offset(cx - r, cy), end = Offset(cx + r, cy), strokeWidth = 1f,
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 6f)))

            // 旋转扫描臂 — 始终绘制（"正在扫描"指示，不再受 variant / 设备数 gate）
            rotate(degrees = sweepAngle, pivot = Offset(cx, cy)) {
                drawLine(
                    brush = Brush.horizontalGradient(
                        0.0f to Lime.copy(alpha = 0f),
                        0.6f to limeArm,
                        1.0f to Lime,
                        startX = cx, endX = cx + r,
                    ),
                    start = Offset(cx, cy),
                    end = Offset(cx + r, cy),
                    strokeWidth = 1.4f,
                )
                // 渐淡扇区
                rotate(degrees = -30f, pivot = Offset(cx, cy)) {
                    drawArcSlice(cx, cy, r, sweepDeg = 30f, color = Lime)
                }
            }

            // 设备点
            devices.forEach { d ->
                val rad = Math.toRadians((d.angleDeg - 90).toDouble()).toFloat()
                val px = cx + cos(rad) * r * d.dist
                val py = cy + sin(rad) * r * d.dist
                val isSel = d.id == selectedId
                val pointColor = if (isSel) Flame else Lime

                if (variant == RadarVariant.PULSE) {
                    val pulseR = (24f + pulsePhase * 28f) * (1f + d.dist * 0.2f)
                    drawCircle(
                        color = pointColor.copy(alpha = 0.30f * (1 - pulsePhase)),
                        radius = pulseR,
                        center = Offset(px, py),
                    )
                } else {
                    drawCircle(color = pointColor.copy(alpha = 0.20f), radius = 22f, center = Offset(px, py))
                }
                // selected: 中心拉虚线
                if (isSel) {
                    drawLine(
                        color = Flame,
                        start = Offset(cx, cy),
                        end = Offset(px, py),
                        strokeWidth = 1.5f,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 4f)),
                    )
                }
                // 实心点
                drawCircle(color = pointColor, radius = 7f, center = Offset(px, py))
            }
        }

        // 罗盘字母（用 Composable Text 摆位置）
        val compassStyle = TextStyle(
            fontFamily = GeistMono, fontWeight = FontWeight.W700,
            fontSize = 9.sp, letterSpacing = 1.4.sp, color = mesh.textTertiary,
        )
        Box(Modifier.fillMaxSize()) {
            Text("N", modifier = Modifier.align(Alignment.TopCenter).padding(top = 2.dp), style = compassStyle)
            Text("S", modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 2.dp), style = compassStyle)
            Text("W", modifier = Modifier.align(Alignment.CenterStart).padding(start = 2.dp), style = compassStyle)
            Text("E", modifier = Modifier.align(Alignment.CenterEnd).padding(end = 2.dp), style = compassStyle)
        }

        // 中心 60×60 黑圆 + YOU
        Box(
            Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(if (mesh.isDark) mesh.cardElevated else Ink),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    "YOU",
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 13.sp, color = Lime, letterSpacing = 1.6.sp,
                    ),
                )
                Text(
                    myIp.takeLastWhile { it != '.' }.let { "·$it" },
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 9.sp, color = mesh.textTertiary,
                    ),
                )
            }
        }

        // 设备 label overlay（device name + RTT）
        devices.forEach { d ->
            DeviceLabel(device = d, radarSizeDp = sizeDp, isSelected = d.id == selectedId, onClick = { onSelect(d.id) })
        }
    }
}

@Composable
private fun DeviceLabel(
    device: MockDevice,
    radarSizeDp: Dp,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val mesh = MeshTheme.colors
    val density = androidx.compose.ui.platform.LocalDensity.current
    val radarPx = with(density) { radarSizeDp.toPx() }
    val r = radarPx / 2f
    val rad = Math.toRadians((device.angleDeg - 90).toDouble()).toFloat()
    val px = (cos(rad) * r * device.dist).toInt()
    val py = (sin(rad) * r * device.dist).toInt()

    Column(
        modifier = Modifier
            .placeAt(px, py)
            .padding(top = 20.dp)
            .clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = device.who,
            style = TextStyle(
                fontFamily = Geist, fontWeight = FontWeight.W600,
                fontSize = 11.sp, color = if (isSelected) mesh.flame else mesh.textPrimary,
            ),
        )
        Text(
            text = "${device.os}·${device.rttMs}ms",
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                fontSize = 9.sp, color = mesh.textTertiary,
            ),
        )
    }
}

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawArcSlice(
    cx: Float, cy: Float, r: Float, sweepDeg: Float, color: Color,
) {
    val brush = Brush.sweepGradient(
        0f to color.copy(alpha = 0f),
        (sweepDeg / 360f) to color.copy(alpha = 0.18f),
        ((sweepDeg + 0.001f) / 360f) to color.copy(alpha = 0f),
        1f to color.copy(alpha = 0f),
    )
    translate(left = cx - r, top = cy - r) {
        drawCircle(brush = brush, radius = r, center = Offset(r, r))
    }
}

private fun Modifier.placeAt(xPx: Int, yPx: Int): Modifier =
    this.layoutOffset { IntOffset(xPx, yPx) }
