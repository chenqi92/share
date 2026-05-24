package com.welape.meshdrop.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import com.welape.meshdrop.wear.ui.NearbyScreen
import com.welape.meshdrop.wear.ui.ReceiveScreen
import com.welape.meshdrop.wear.ui.theme.MDColor

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // intent extra "screen"=receive 用于截图脚本直接进 Receive 页
        val start = when (intent?.getStringExtra("screen")) {
            "receive" -> WearScreen.Receive
            else -> WearScreen.Nearby
        }
        setContent { MeshDropWearRoot(start) }
    }
}

@Composable
fun MeshDropWearRoot(initial: WearScreen = WearScreen.Nearby) {
    var screen by remember { mutableStateOf(initial) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink)
            .pointerInput(Unit) {
                detectTapGestures(
                    onLongPress = {
                        screen = if (screen == WearScreen.Nearby) WearScreen.Receive else WearScreen.Nearby
                    },
                )
            },
    ) {
        when (screen) {
            WearScreen.Nearby -> NearbyScreen(onOpenReceive = { screen = WearScreen.Receive })
            WearScreen.Receive -> ReceiveScreen(
                onAccept = { screen = WearScreen.Nearby },
                onReject = { screen = WearScreen.Nearby },
            )
        }
    }
}

enum class WearScreen { Nearby, Receive }
