package com.welape.meshdrop.wear.ui

import androidx.compose.ui.graphics.Color
import com.welape.meshdrop.wear.bridge.Device

/**
 * UI 用的设备视图，把 [Device] 协议字段映射成圆屏 radar 上能用的几何/颜色。
 */
data class DeviceUi(
    val id: String,
    val name: String,
    val initials: String,
    val color: Color,
    val angleDeg: Float,
    val dist: Float,
    val kindLabel: String,
)

private val deviceColors = listOf(
    Color(0xFFFFB4A1),
    Color(0xFFB7E5C8),
    Color(0xFFC7B8FF),
    Color(0xFFFFD970),
    Color(0xFF9AD0FF),
    Color(0xFFE6A0FF),
    Color(0xFFFF9C7A),
    Color(0xFF7AD8C5),
)

private fun Device.initials(): String {
    val name = displayName.ifBlank { id }
    val parts = name.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }
    return when {
        parts.size >= 2 -> (parts[0].take(1) + parts[1].take(1)).uppercase()
        parts.size == 1 -> parts[0].take(2).uppercase()
        else -> "?"
    }
}

private fun Device.kindLabel(): String = when (kind.lowercase()) {
    "mac" -> "macOS"
    "ios" -> "iOS"
    "ipad" -> "iPadOS"
    "android" -> "Android"
    "win" -> "Windows"
    "linux" -> "Linux"
    "tv" -> "tvOS"
    "vision" -> "visionOS"
    "watch" -> "watchOS"
    "wear" -> "Wear OS"
    "web" -> "Web"
    else -> kind
}

fun List<Device>.toUi(): List<DeviceUi> {
    val total = size.coerceAtLeast(1)
    return mapIndexed { idx, d ->
        val angle = (360f * idx / total + d.id.stableSeed() % 30) % 360f
        val dist = 0.40f + ((d.id.stableSeed() / 7) % 50) / 100f  // 0.40 ~ 0.89
        DeviceUi(
            id = d.id,
            name = d.displayName.ifBlank { d.id },
            initials = d.initials(),
            color = deviceColors[(d.id.stableSeed() % deviceColors.size).toInt()],
            angleDeg = angle,
            dist = dist,
            kindLabel = d.kindLabel(),
        )
    }
}

private fun String.stableSeed(): Long {
    var h = 0L
    // 用位掩码把符号位清掉，避免 abs(Long.MIN_VALUE) 仍为负导致索引越界
    for (c in this) h = (h * 31 + c.code) and 0x7FFFFFFFFFFFFFFFL
    return h
}
