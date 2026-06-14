package com.welape.meshdrop.wear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.welape.meshdrop.wear.R
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType

/**
 * 快捷消息列表 —— emoji 项不属于可翻译文本，保留原样；可读短句走 i18n。
 *
 * Wear OS 屏幕小、键盘体验差，预制快捷消息是"便捷发送"的最稳实装；
 * 后续可以接 RemoteInput 加语音输入选项。
 */
@Composable
private fun quickMessages(): List<String> = listOf(
    "👋",
    stringResource(R.string.quicksend_ok),
    stringResource(R.string.quicksend_on_the_way),
    stringResource(R.string.quicksend_later),
    "❤️",
)

@Composable
fun QuickSendSheet(
    peerName: String,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink.copy(alpha = 0.96f))
            .clickable { onDismiss() },
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "→ $peerName",
                color = MDColor.lime,
                style = MDType.mono(10f, FontWeight.Bold, tracking = 1.4f),
            )
            Spacer(modifier = Modifier.height(6.dp))
            val messages = quickMessages()
            LazyColumn(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                items(messages) { msg ->
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MDColor.dink2, RoundedCornerShape(16.dp))
                            .clickable { onPick(msg) }
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = msg,
                            color = MDColor.dpaper,
                            style = MDType.body(13f, FontWeight.Medium),
                        )
                    }
                }
            }
        }
    }
}
