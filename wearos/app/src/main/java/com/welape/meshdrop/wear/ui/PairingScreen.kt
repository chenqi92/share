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
import com.welape.meshdrop.wear.bridge.Pairing
import com.welape.meshdrop.wear.bridge.WearEngineProxy
import com.welape.meshdrop.wear.components.Avatar
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType
import kotlinx.coroutines.launch

/**
 * 配对待审页 —— 呼应 phone 端推送的 pairing_pending 事件。
 * 接收端显式确认配对（TOFU 信任流）是协议不变量，必须在表上可呈现/响应。
 */
@Composable
fun PairingScreen(
    onResolved: () -> Unit = {},
) {
    val proxy = remember { WearEngineProxy.instance }
    val pairings by proxy.pendingPairings.collectAsState()
    val isOnline by proxy.isOnline.collectAsState()
    val scope = rememberCoroutineScope()

    val pairing = pairings.firstOrNull()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink),
        contentAlignment = Alignment.Center,
    ) {
        when {
            !isOnline -> CenterHint(
                title = stringResource(R.string.discovery_offline_title).uppercase(),
                titleColor = MDColor.flame,
                sub = stringResource(R.string.discovery_offline_tip),
            )
            pairing == null -> CenterHint(
                title = stringResource(R.string.pairing_empty_title),
                titleColor = MDColor.dpaper,
                sub = stringResource(R.string.pairing_empty_sub).uppercase(),
                onTap = onResolved,
            )
            else -> PairingCard(
                pairing = pairing,
                onAccept = {
                    scope.launch {
                        proxy.acceptPairing(pairing.id)
                        onResolved()
                    }
                },
                onReject = {
                    scope.launch {
                        proxy.rejectPairing(pairing.id)
                        onResolved()
                    }
                },
            )
        }
    }
}

@Composable
private fun PairingCard(
    pairing: Pairing,
    onAccept: () -> Unit,
    onReject: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(modifier = Modifier.size(5.dp).background(MDColor.sky, CircleShape))
            Text(
                // 顶部标签恒为大写呈现，文案由 i18n 提供
                text = stringResource(R.string.pairing_label).uppercase(),
                color = MDColor.sky,
                style = MDType.mono(9f, FontWeight.Bold, tracking = 1.2f),
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Avatar(
                initials = pairing.peerName.take(1).ifBlank { "?" },
                color = Color(0xFF9AD0FF),
                sizeDp = 26,
                ring = true,
                ringColor = MDColor.sky,
            )
            Column {
                Text(
                    text = pairing.peerName.ifBlank { stringResource(R.string.pairing_unknown_device) },
                    color = MDColor.dpaper,
                    style = MDType.display(13f, FontWeight.Bold),
                )
                Text(
                    // TOFU 为协议常量（首次信任模型），不翻译；有配对码时展示本地化标签
                    text = if (pairing.code.isNotBlank())
                        stringResource(R.string.pairing_code, pairing.code).uppercase()
                    else "TOFU",
                    color = MDColor.dim,
                    style = MDType.mono(8f, FontWeight.Medium, tracking = 1.0f),
                )
            }
        }

        // 指纹 4 字符分组大写，便于人工核对
        Text(
            text = groupFingerprint(pairing.fingerprint),
            color = MDColor.muted,
            style = MDType.mono(9f, FontWeight.Medium, tracking = 0.8f),
            modifier = Modifier.fillMaxWidth(),
        )

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
                Text(text = stringResource(R.string.common_trust), color = MDColor.dink, style = MDType.display(13f, FontWeight.Bold))
            }
        }
    }
}

@Composable
private fun CenterHint(
    title: String,
    titleColor: Color,
    sub: String,
    onTap: (() -> Unit)? = null,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = if (onTap != null) Modifier.clickable { onTap() } else Modifier,
    ) {
        Text(
            text = title,
            color = titleColor,
            style = MDType.display(16f, FontWeight.Bold),
        )
        Text(
            text = sub,
            color = MDColor.muted,
            style = MDType.mono(10f, FontWeight.Medium, tracking = 1.2f),
        )
    }
}

/** 把 32 hex 指纹按 4 字符一组、大写展示，便于人工比对。 */
private fun groupFingerprint(fp: String): String =
    fp.uppercase().chunked(4).joinToString(" ")
