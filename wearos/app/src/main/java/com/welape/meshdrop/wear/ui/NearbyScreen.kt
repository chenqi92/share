package com.welape.meshdrop.wear.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.welape.meshdrop.wear.bridge.WearEngineProxy
import com.welape.meshdrop.wear.components.Avatar
import com.welape.meshdrop.wear.components.MeshDropMark
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType
import kotlinx.coroutines.launch
import androidx.compose.runtime.collectAsState
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

@Composable
fun NearbyScreen(
    onPick: (String) -> Unit = {},
    onOpenReceive: () -> Unit = {},
) {
    val proxy = remember { WearEngineProxy.instance }
    val devices by proxy.devices.collectAsState()
    val isOnline by proxy.isOnline.collectAsState()
    val lastError by proxy.lastError.collectAsState()
    val scope = rememberCoroutineScope()

    val uiDevices = remember(devices) { devices.toUi() }
    var focusIndex by remember { mutableIntStateOf(0) }
    var quickSendTarget by remember { mutableStateOf<DeviceUi?>(null) }
    LaunchedEffect(uiDevices.size) {
        if (focusIndex >= uiDevices.size) focusIndex = 0
    }

    NearbyContent(
        uiDevices = uiDevices,
        focusIndex = focusIndex,
        isOnline = isOnline,
        lastError = lastError,
        onPick = { idx ->
            focusIndex = idx
            val target = uiDevices.getOrNull(idx) ?: return@NearbyContent
            onPick(target.id)
            quickSendTarget = target
        },
        onOpenReceive = onOpenReceive,
    )

    quickSendTarget?.let { target ->
        QuickSendSheet(
            peerName = target.name,
            onPick = { msg ->
                quickSendTarget = null
                scope.launch { proxy.sendText(target.id, msg) }
            },
            onDismiss = { quickSendTarget = null },
        )
    }
}

@Composable
internal fun NearbyContent(
    uiDevices: List<DeviceUi>,
    focusIndex: Int,
    isOnline: Boolean,
    lastError: String?,
    onPick: (Int) -> Unit,
    onOpenReceive: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink),
        contentAlignment = Alignment.Center,
    ) {
        RadarBackdrop()

        // 顶部 logo + 在线/离线指示
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
                    .background(
                        if (isOnline) MDColor.lime else MDColor.muted,
                        CircleShape,
                    ),
            )
        }

        // 中心数字 + NEARBY / OFFLINE
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = if (isOnline) "${uiDevices.size}" else "—",
                color = if (isOnline) MDColor.dpaper else MDColor.muted,
                style = MDType.display(46f, FontWeight.Bold),
            )
            Spacer(modifier = Modifier.height(2.dp))
            Box(
                modifier = Modifier
                    .background(MDColor.dink3, RoundedCornerShape(999.dp))
                    .padding(horizontal = 8.dp, vertical = 2.dp),
            ) {
                Text(
                    text = if (isOnline) "NEARBY" else "OFFLINE",
                    color = if (isOnline) MDColor.lime else MDColor.flame,
                    style = MDType.mono(10f, FontWeight.Bold, tracking = 2.0f),
                )
            }
        }

        // avatar 沿圆环放置
        if (isOnline && uiDevices.isNotEmpty()) {
            val density = LocalDensity.current
            val minRadiusDp = 46f
            val maxRadiusDp = 76f
            Box(modifier = Modifier.fillMaxSize()) {
                uiDevices.forEachIndexed { idx, d ->
                    val angleRad = Math.toRadians(d.angleDeg.toDouble() - 90.0)
                    val r = minRadiusDp + (maxRadiusDp - minRadiusDp) * d.dist
                    val radiusPx = with(density) { r.dp.toPx() }
                    val dx = (radiusPx * cos(angleRad)).toFloat()
                    val dy = (radiusPx * sin(angleRad)).toFloat()
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Box(
                            modifier = Modifier
                                .offset { IntOffset(dx.roundToInt(), dy.roundToInt()) }
                                .clickable { onPick(idx) },
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
        }

        // 底部 hint
        val hint = when {
            !isOnline -> "OFFLINE · phone 不在身边"
            uiDevices.isEmpty() -> "附近没有 MeshDrop 设备"
            lastError == "timeout" -> "命令超时 · 检查 phone"
            else -> "转表冠选 · 按发"
        }
        Text(
            text = hint,
            color = if (isOnline && lastError != "timeout") MDColor.muted else MDColor.flame,
            style = MDType.mono(10f, FontWeight.Medium, tracking = 1.2f),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 22.dp)
                .clickable { onOpenReceive() },
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
        for (i in 1..3) {
            drawCircle(
                color = MDColor.lime.copy(alpha = 0.07f),
                radius = maxR * (i / 3f),
                center = Offset(cx, cy),
                style = Stroke(width = 0.8f),
            )
        }
        val angleRad = Math.toRadians(-65.0)
        val ex = cx + (maxR * cos(angleRad)).toFloat()
        val ey = cy + (maxR * sin(angleRad)).toFloat()
        drawLine(
            color = MDColor.lime.copy(alpha = 0.22f),
            start = Offset(cx, cy),
            end = Offset(ex, ey),
            strokeWidth = 6f,
        )
        drawLine(MDColor.dline, Offset(cx, 6f), Offset(cx, h - 6f), strokeWidth = 0.6f)
        drawLine(MDColor.dline, Offset(6f, cy), Offset(w - 6f, cy), strokeWidth = 0.6f)
    }
}
