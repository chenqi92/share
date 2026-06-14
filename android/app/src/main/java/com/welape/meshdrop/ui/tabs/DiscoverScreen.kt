package com.welape.meshdrop.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.mock.MockDevices
import com.welape.meshdrop.mock.MockMeData
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.DeviceRow
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.MeshDropWordmark
import com.welape.meshdrop.ui.components.MeshIconBtn
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.components.Radar
import com.welape.meshdrop.ui.components.RadarVariant
import com.welape.meshdrop.ui.theme.ErrorRed
import com.welape.meshdrop.ui.theme.Flame
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@Composable
fun DiscoverScreen(
    selectedId: String?,
    onSelect: (String) -> Unit,
    onTapDevice: (String) -> Unit = {},
    devices: List<MockDevice> = MockDevices,
    isStarting: Boolean = false,
    lastError: String? = null,
    onDismissError: () -> Unit = {},
) {
    val mesh = MeshTheme.colors
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(mesh.canvas)
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(horizontal = 20.dp)),
    ) {
        Spacer(Modifier.height(12.dp))
        // Top bar
        Row(verticalAlignment = Alignment.CenterVertically) {
            MeshDropWordmark(fontSize = 22.sp)
            Spacer(Modifier.weight(1f))
            MeshIconBtn(icon = Icons.Outlined.Search, contentDescription = "搜索", bordered = true, sizeDp = 36.dp)
            Spacer(Modifier.width(8.dp))
            MeshIconBtn(icon = Icons.Outlined.MoreHoriz, contentDescription = "更多", bordered = true, sizeDp = 36.dp)
        }

        Spacer(Modifier.height(20.dp))

        if (isStarting) ScanningBanner()
        if (lastError != null) ErrorSnack(lastError, onDismissError)

        // 状态条
        StatusStrip(visibility = MockMeData.visibility, peers = devices.size)

        Spacer(Modifier.height(18.dp))

        // Hero 标题
        Text(
            text = "附近的",
            style = TextStyle(
                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                fontSize = 26.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
            ),
        )

        // 渐变数字（flame -> lime）
        val gradient = Brush.horizontalGradient(listOf(Flame, LimeDeep, Lime))
        Text(
            text = "${devices.size} 台设备",
            style = TextStyle(
                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                fontSize = 38.sp, letterSpacing = (-0.6).sp,
                brush = gradient,
            ),
        )
        Text(
            text = if (isStarting) "扫描中 · scanning LAN…" else "LAN-only · ${devices.size} peers",
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                fontSize = 11.sp, color = mesh.textTertiary, letterSpacing = 0.4.sp,
            ),
        )

        Spacer(Modifier.height(18.dp))

        // 雷达
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 6.dp),
            contentAlignment = Alignment.Center,
        ) {
            Radar(
                devices = devices,
                selectedId = selectedId,
                variant = if (selectedId != null) RadarVariant.SWEEP else RadarVariant.PULSE,
                sizeDp = 300.dp,
                myIp = MockMeData.ip,
                onSelect = onSelect,
            )
        }

        Spacer(Modifier.height(10.dp))

        Text(
            text = if (devices.isEmpty() && !isStarting) "↑ 附近没有 MeshDrop 设备" else "↑ 长按设备开始发送",
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                fontSize = 10.sp, color = mesh.textTertiary, letterSpacing = 1.2.sp,
            ),
        )

        Spacer(Modifier.height(20.dp))

        AsciiDivider(label = "附近 · NEARBY · ${devices.size}")

        if (devices.isEmpty() && !isStarting) {
            EmptyNearbyCard()
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                devices.forEach { dev ->
                    DeviceRow(
                        device = dev,
                        selected = dev.id == selectedId,
                        onClick = { onTapDevice(dev.id) },
                    )
                }
            }
        }

        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun ScanningBanner() {
    val mesh = MeshTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(mesh.limeFill)
            .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(LimeDeep),
        )
        Text(
            text = "扫描中 · scanning LAN…",
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W700,
                fontSize = 11.sp, color = mesh.textPrimary, letterSpacing = 1.0.sp,
            ),
        )
    }
    Spacer(Modifier.height(10.dp))
}

@Composable
private fun ErrorSnack(message: String, onDismiss: () -> Unit) {
    val mesh = MeshTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .border(1.dp, ErrorRed.copy(alpha = 0.6f), RoundedCornerShape(10.dp))
            .background(ErrorRed.copy(alpha = 0.08f))
            .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "网络出错",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W700,
                    fontSize = 11.sp, color = ErrorRed, letterSpacing = 1.0.sp,
                ),
            )
            Text(
                text = message,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 11.sp, color = mesh.textSecondary,
                ),
            )
        }
        MeshIconBtn(icon = Icons.Outlined.Close, contentDescription = "关闭", sizeDp = 28.dp, onClick = onDismiss)
    }
    Spacer(Modifier.height(10.dp))
}

@Composable
private fun EmptyNearbyCard() {
    val mesh = MeshTheme.colors
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, mesh.outline, RoundedCornerShape(14.dp))
            .background(mesh.card)
            .padding(PaddingValues(horizontal = 18.dp, vertical = 22.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "附近没有 MeshDrop 设备",
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 16.sp, color = mesh.textPrimary,
                ),
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = "让朋友也打开试试 · invite a friend to open",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 11.sp, color = mesh.textTertiary,
                ),
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun StatusStrip(visibility: String, peers: Int) {
    val mesh = MeshTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(mesh.surface)
            .border(1.dp, mesh.outline, RoundedCornerShape(12.dp))
            .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            Modifier
                .size(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(Lime),
        )
        MonoLabel("LIVE")
        Spacer(Modifier.width(8.dp))
        Text(
            text = visibility,
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                fontSize = 11.sp, color = mesh.textSecondary,
            ),
        )
        Spacer(Modifier.weight(1f))
        MeshChip(text = "LAN ONLY", tone = ChipTone.OUTLINE, mono = true)
    }
}
