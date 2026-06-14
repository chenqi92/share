package com.welape.meshdrop.wear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.welape.meshdrop.wear.R
import com.welape.meshdrop.wear.bridge.Offer
import com.welape.meshdrop.wear.bridge.WearEngineProxy
import com.welape.meshdrop.wear.components.Avatar
import com.welape.meshdrop.wear.components.FileChipMini
import com.welape.meshdrop.wear.components.MonoTag
import com.welape.meshdrop.wear.components.Tone
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType
import kotlinx.coroutines.launch

@Composable
fun ReceiveScreen(
    onAccept: () -> Unit = {},
    onReject: () -> Unit = {},
) {
    val proxy = remember { WearEngineProxy.instance }
    val offers by proxy.pendingOffers.collectAsState()
    val isOnline by proxy.isOnline.collectAsState()
    val scope = rememberCoroutineScope()

    val offer = offers.firstOrNull()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink),
        contentAlignment = Alignment.Center,
    ) {
        when {
            !isOnline -> OfflineHint()
            offer == null -> EmptyHint(onBack = onAccept)
            else -> OfferCard(
                offer = offer,
                onAccept = {
                    scope.launch {
                        proxy.acceptOffer(offer.id)
                        onAccept()
                    }
                },
                onReject = {
                    scope.launch {
                        proxy.rejectOffer(offer.id)
                        onReject()
                    }
                },
            )
        }
    }
}

@Composable
private fun OfferCard(
    offer: Offer,
    onAccept: () -> Unit,
    onReject: () -> Unit,
) {
    val firstFile = offer.files.firstOrNull()
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 30.dp, vertical = 26.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(3.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(modifier = Modifier.size(5.dp).background(MDColor.lime, CircleShape))
                Text(
                    // 标签恒为大写呈现，文案由 i18n 提供
                    text = stringResource(R.string.receive_from).uppercase(),
                    color = MDColor.lime,
                    style = MDType.mono(9f, FontWeight.Bold, tracking = 1.6f),
                )
            }
            // v0.1 LAN 为明文 TCP，不得宣称端到端加密——如实标注传输状态
            MonoTag(text = "LAN", tone = Tone.Ink)
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Avatar(
                initials = offer.peerName.take(1).ifBlank { "?" },
                color = Color(0xFFFFB4A1),
                sizeDp = 28,
                ring = true,
                ringColor = MDColor.lime,
            )
            Column {
                Text(
                    text = offer.peerName.ifBlank { offer.peerId },
                    color = MDColor.dpaper,
                    style = MDType.display(14f, FontWeight.Bold),
                )
                Text(
                    text = offer.kind.uppercase(),
                    color = MDColor.dim,
                    style = MDType.mono(8f, FontWeight.Medium, tracking = 1.0f),
                )
            }
        }

        if (firstFile != null) {
            val ext = firstFile.name.substringAfterLast('.', missingDelimiterValue = "bin")
            FileChipMini(
                name = firstFile.name,
                size = humanSize(firstFile.sizeBytes),
                ext = ext,
                modifier = Modifier.fillMaxWidth(),
            )
        } else if (!offer.noteText.isNullOrBlank()) {
            Text(
                text = offer.noteText,
                color = MDColor.dpaper,
                style = MDType.body(11f, FontWeight.Medium),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 2.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(30.dp)
                    .background(MDColor.dink3, CircleShape)
                    .border(0.5.dp, MDColor.dline, CircleShape)
                    .clickable { onReject() },
                contentAlignment = Alignment.Center,
            ) {
                Text(text = "×", color = MDColor.dpaper, style = MDType.display(16f, FontWeight.Bold))
            }
            Row(
                modifier = Modifier
                    .weight(1f)
                    .height(30.dp)
                    .background(MDColor.lime, RoundedCornerShape(999.dp))
                    .clickable { onAccept() },
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(text = stringResource(R.string.common_accept), color = MDColor.dink, style = MDType.display(13f, FontWeight.Bold))
            }
        }
    }
}

@Composable
private fun OfflineHint() {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            // 标签恒为大写呈现，文案由 i18n 提供
            text = stringResource(R.string.discovery_offline_title).uppercase(),
            color = MDColor.flame,
            style = MDType.mono(14f, FontWeight.Bold, tracking = 2.0f),
        )
        Text(
            text = stringResource(R.string.discovery_offline_tip),
            color = MDColor.muted,
            style = MDType.body(10f, FontWeight.Medium),
        )
    }
}

@Composable
private fun EmptyHint(onBack: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier.clickable { onBack() },
    ) {
        Text(
            text = stringResource(R.string.receive_empty_title),
            color = MDColor.dpaper,
            style = MDType.display(16f, FontWeight.Bold),
        )
        Text(
            // 返回链接恒为大写呈现，文案由 i18n 提供
            text = stringResource(R.string.receive_empty_back).uppercase(),
            color = MDColor.lime,
            style = MDType.mono(10f, FontWeight.Medium, tracking = 1.4f),
        )
    }
}

private fun humanSize(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val kb = bytes / 1024.0
    if (kb < 1024) return String.format("%.1f KB", kb)
    val mb = kb / 1024.0
    if (mb < 1024) return String.format("%.1f MB", mb)
    val gb = mb / 1024.0
    return String.format("%.1f GB", gb)
}
