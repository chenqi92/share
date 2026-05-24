package com.welape.meshdrop.ui

import androidx.activity.ComponentActivity
import androidx.compose.material3.windowsizeclass.ExperimentalMaterial3WindowSizeClassApi
import androidx.compose.material3.windowsizeclass.WindowWidthSizeClass
import androidx.compose.material3.windowsizeclass.calculateWindowSizeClass
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext
import com.welape.meshdrop.ShareApplication
import com.welape.meshdrop.transport.ShareEngine

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
    val engine: ShareEngine? = (LocalContext.current.applicationContext as? ShareApplication)?.engine
    val isTablet = when (forceLayout) {
        "phone" -> false
        "tablet" -> true
        else -> {
            val wsc = calculateWindowSizeClass(activity)
            wsc.widthSizeClass != WindowWidthSizeClass.Compact
        }
    }
    if (isTablet) TabletRoot(state, engine) else PhoneRoot(state, engine)
}
