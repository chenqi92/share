package com.welape.meshdrop.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * MeshDrop 设计语意配色（不依赖 Material 默认蓝紫）。
 *
 * 直接通过 `LocalMeshColors.current` 取色；MaterialTheme 仅提供
 * 字体 / 形状 / 必要的 surface fallback。**dynamicColor 永远关掉**。
 */
data class MeshColors(
    // 文字层级
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val textDisabled: Color,
    // 背景层级
    val canvas: Color,        // 主背景（paper / dink）
    val surface: Color,       // 次背景（paper2 / dink2）
    val card: Color,          // 卡片底（card / dink2）
    val cardElevated: Color,  // 凸起卡片
    val divider: Color,
    val outline: Color,
    val glass: Color,
    // 三色 accent（不随主题切换语义）
    val lime: Color,
    val limeDeep: Color,
    val limeFill: Color,
    val flame: Color,
    val flameDeep: Color,
    val sky: Color,
    val danger: Color,
    // outgoing 气泡（亮 = ink 黑 / 暗 = lime）
    val outgoingBubble: Color,
    val outgoingText: Color,
    val incomingBubble: Color,
    val incomingText: Color,
    val isDark: Boolean,
)

private val Light = MeshColors(
    textPrimary = Ink,
    textSecondary = Ink60,
    textTertiary = Ink45,
    textDisabled = Ink30,
    canvas = Paper,
    surface = Paper2,
    card = CardLt,
    cardElevated = CardLt,
    divider = LineLt,
    outline = Ink12,
    glass = GlassLt,
    lime = Lime,
    limeDeep = LimeDeep,
    limeFill = LimeFillLt,
    flame = Flame,
    flameDeep = FlameDeep,
    sky = Sky,
    danger = ErrorRed,
    outgoingBubble = Ink,
    outgoingText = Paper,
    incomingBubble = CardLt,
    incomingText = Ink,
    isDark = false,
)

private val Dark = MeshColors(
    textPrimary = Dpaper,
    textSecondary = Dpaper60,
    textTertiary = Dpaper45,
    textDisabled = Color(0x40E8E3D6),
    canvas = Dink,
    surface = Dink2,
    card = Dink2,
    cardElevated = Dink3,
    divider = DlineSt,
    outline = DlineSt,
    glass = GlassDk,
    lime = Lime,
    limeDeep = LimeDeep,
    limeFill = LimeFillDk,
    flame = Flame,
    flameDeep = FlameDeep,
    sky = Sky,
    danger = ErrorRed,
    outgoingBubble = Lime,      // 暗色 outgoing 气泡是 lime
    outgoingText = Ink,
    incomingBubble = DincomingBubble, // §6：白色 ~7% 半透明叠加，而非不透明实色
    incomingText = Dpaper,
    isDark = true,
)

val LocalMeshColors = staticCompositionLocalOf { Light }

/** 全应用的主题入口。永远关 dynamicColor。 */
@Composable
fun MeshDropTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val mesh = if (darkTheme) Dark else Light

    // Material color scheme 仅作为 fallback；任何 MeshDrop 渲染都直接用 LocalMeshColors。
    val materialScheme = if (darkTheme) {
        darkColorScheme(
            primary = mesh.lime, onPrimary = Ink,
            secondary = mesh.flame, onSecondary = Paper,
            tertiary = mesh.sky, onTertiary = Ink,
            background = mesh.canvas, onBackground = mesh.textPrimary,
            surface = mesh.surface, onSurface = mesh.textPrimary,
            surfaceVariant = mesh.cardElevated, onSurfaceVariant = mesh.textSecondary,
            outline = mesh.outline, outlineVariant = mesh.divider,
            error = mesh.danger, onError = Paper,
        )
    } else {
        lightColorScheme(
            primary = LimeDeep, onPrimary = Ink,
            secondary = mesh.flame, onSecondary = Paper,
            tertiary = mesh.sky, onTertiary = Ink,
            background = mesh.canvas, onBackground = mesh.textPrimary,
            surface = mesh.card, onSurface = mesh.textPrimary,
            surfaceVariant = mesh.surface, onSurfaceVariant = mesh.textSecondary,
            outline = mesh.outline, outlineVariant = mesh.divider,
            error = mesh.danger, onError = Paper,
        )
    }

    CompositionLocalProvider(LocalMeshColors provides mesh) {
        MaterialTheme(
            colorScheme = materialScheme,
            typography = MeshTypography,
            content = content,
        )
    }
}

/** 短方法。 */
object MeshTheme {
    val colors: MeshColors
        @Composable get() = LocalMeshColors.current
}
