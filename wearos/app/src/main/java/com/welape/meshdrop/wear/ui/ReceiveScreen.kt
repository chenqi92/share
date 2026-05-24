package com.welape.meshdrop.wear.ui

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.welape.meshdrop.wear.components.Avatar
import com.welape.meshdrop.wear.components.FileChipMini
import com.welape.meshdrop.wear.components.MonoTag
import com.welape.meshdrop.wear.components.Tone
import com.welape.meshdrop.wear.mock.Mock
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType

@Composable
fun ReceiveScreen(
    onAccept: () -> Unit = {},
    onReject: () -> Unit = {},
) {
    val offer = Mock.pendingOffer
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MDColor.dink),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                // 圆屏：四角不可见，水平方向比上下需要更多 inset
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
                        text = "FROM",
                        color = MDColor.lime,
                        style = MDType.mono(9f, FontWeight.Bold, tracking = 1.6f),
                    )
                }
                MonoTag(text = "E2E", tone = Tone.Ink)
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Avatar(
                    initials = "李",
                    color = Color(0xFFFFB4A1),
                    sizeDp = 28,
                    ring = true,
                    ringColor = MDColor.lime,
                )
                Column(
                    verticalArrangement = Arrangement.spacedBy(0.dp),
                ) {
                    Text(
                        text = offer.peer,
                        color = MDColor.dpaper,
                        style = MDType.display(14f, FontWeight.Bold),
                    )
                    Text(
                        text = "macOS",
                        color = MDColor.dim,
                        style = MDType.mono(8f, FontWeight.Medium, tracking = 1.0f),
                    )
                }
            }

            FileChipMini(
                name = offer.fileName,
                size = offer.fileSize,
                ext = offer.ext,
                modifier = Modifier.fillMaxWidth(),
            )

            // 双 CTA
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
                    Text(text = "接收 ✓", color = MDColor.dink, style = MDType.display(13f, FontWeight.Bold))
                }
            }
        }
    }
}
