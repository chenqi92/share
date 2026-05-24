package com.welape.meshdrop.ui

import androidx.activity.ComponentActivity
import androidx.compose.material3.windowsizeclass.ExperimentalMaterial3WindowSizeClassApi
import androidx.compose.material3.windowsizeclass.WindowWidthSizeClass
import androidx.compose.material3.windowsizeclass.calculateWindowSizeClass
import androidx.compose.runtime.Composable

/**
 * 入口分发：Compact → Phone，Medium/Expanded → Tablet 双栏。
 *
 * @param forceLayout 截图阶段强制布局（"phone" / "tablet"），运行时 null = auto。
 */
@OptIn(ExperimentalMaterial3WindowSizeClassApi::class)
@Composable
fun MeshDropApp(
    activity: ComponentActivity,
    forceLayout: String? = null,
) {
    val state = rememberMeshAppState()
    val isTablet = when (forceLayout) {
        "phone" -> false
        "tablet" -> true
        else -> {
            val wsc = calculateWindowSizeClass(activity)
            wsc.widthSizeClass != WindowWidthSizeClass.Compact
        }
    }
    if (isTablet) TabletRoot(state) else PhoneRoot(state)
}
