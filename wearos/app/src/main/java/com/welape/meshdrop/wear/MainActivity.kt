package com.welape.meshdrop.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.welape.meshdrop.wear.bridge.WearEngineProxy
import com.welape.meshdrop.wear.ui.NearbyScreen
import com.welape.meshdrop.wear.ui.PairingScreen
import com.welape.meshdrop.wear.ui.ReceiveScreen
import com.welape.meshdrop.wear.ui.theme.MDColor
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // intent extra "screen" 用于截图脚本直接进指定页
        val start = when (intent?.getStringExtra("screen")) {
            "receive" -> WearScreen.Receive
            "pairing" -> WearScreen.Pairing
            else -> WearScreen.Nearby
        }
        setContent { MeshDropWearRoot(start) }
    }
}

@Composable
fun MeshDropWearRoot(initial: WearScreen = WearScreen.Nearby) {
    val proxy = remember { WearEngineProxy.instance }
    val pendingPairings by proxy.pendingPairings.collectAsState()
    val pendingOffers by proxy.pendingOffers.collectAsState()

    val pages = WearScreen.entries
    val pagerState = rememberPagerState(initialPage = initial.ordinal, pageCount = { pages.size })
    val scope = rememberCoroutineScope()

    // 收到待审配对时主动翻到 Pairing 页，避免事件无可见入口被忽略
    LaunchedEffect(pendingPairings.isNotEmpty()) {
        if (pendingPairings.isNotEmpty()) {
            pagerState.animateScrollToPage(WearScreen.Pairing.ordinal)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink),
    ) {
        HorizontalPager(state = pagerState) { page ->
            when (pages[page]) {
                WearScreen.Nearby -> NearbyScreen(
                    onOpenReceive = {
                        scope.launch { pagerState.animateScrollToPage(WearScreen.Receive.ordinal) }
                    },
                )
                WearScreen.Receive -> ReceiveScreen(
                    onAccept = {
                        scope.launch { pagerState.animateScrollToPage(WearScreen.Nearby.ordinal) }
                    },
                    onReject = {
                        scope.launch { pagerState.animateScrollToPage(WearScreen.Nearby.ordinal) }
                    },
                )
                WearScreen.Pairing -> PairingScreen(
                    onResolved = {
                        scope.launch { pagerState.animateScrollToPage(WearScreen.Nearby.ordinal) }
                    },
                )
            }
        }

        // 可见页码指示：左右滑切页，红点表示对应页有待审项
        PageDots(
            count = pages.size,
            current = pagerState.currentPage,
            alert = buildSet {
                if (pendingOffers.isNotEmpty()) add(WearScreen.Receive.ordinal)
                if (pendingPairings.isNotEmpty()) add(WearScreen.Pairing.ordinal)
            },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 6.dp),
        )
    }
}

@Composable
private fun PageDots(
    count: Int,
    current: Int,
    alert: Set<Int>,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(count) { i ->
            val color = when {
                alert.contains(i) -> MDColor.flame
                i == current -> MDColor.lime
                else -> MDColor.dim
            }
            Box(
                modifier = Modifier
                    .size(if (i == current) 5.dp else 4.dp)
                    .background(color, CircleShape),
            )
        }
    }
}

enum class WearScreen { Nearby, Receive, Pairing }
