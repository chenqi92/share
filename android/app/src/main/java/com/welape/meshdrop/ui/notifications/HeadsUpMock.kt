package com.welape.meshdrop.ui.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.R
import com.welape.meshdrop.ui.components.FileGlyph
import com.welape.meshdrop.ui.components.MeshDropMark
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme

/**
 * 静态 mock：模拟 Android 13+ heads-up 通知样式（顶部圆角卡 + 三按钮）。
 * 仅用于 PR 截图占位；真实通知见 [com.welape.meshdrop.notifications.IncomingChannel]。
 */
@Composable
fun HeadsUpMockCollapsed() {
    Background {
        NotifCard(expanded = false)
    }
}

@Composable
fun HeadsUpMockExpanded() {
    Background {
        NotifCard(expanded = true)
    }
}

@Composable
private fun Background(content: @Composable () -> Unit) {
    // 模拟 Android 锁屏壁纸渐变背景
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                androidx.compose.ui.graphics.Brush.verticalGradient(
                    listOf(Color(0xFF18121A), Color(0xFF2A1B0A), Color(0xFF1A1308)),
                ),
            ),
    ) {
        // 顶部状态条
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(PaddingValues(horizontal = 18.dp, vertical = 10.dp)),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                "14:08",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W600,
                    fontSize = 13.sp, color = Color.White,
                ),
            )
            Spacer(Modifier.weight(1f))
            Text(
                "·  ●●●●  ●●  ●",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = Color(0xCCFFFFFF), letterSpacing = 1.sp,
                ),
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 56.dp, start = 12.dp, end = 12.dp),
        ) {
            content()
        }
    }
}

@Composable
private fun NotifCard(expanded: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(28.dp))
            .background(Color(0xFF2A2A2A))
            .padding(PaddingValues(horizontal = 18.dp, vertical = 14.dp)),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // 头部：图标 + 应用名 + 时间
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(22.dp)
                    .clip(RoundedCornerShape(6.dp))
                    .background(Color(0xFFF5F2EC))
                    .padding(2.dp),
                contentAlignment = Alignment.Center,
            ) {
                MeshDropMark(size = 18.dp, strokeColor = Color(0xFF0A0A0A), dotColor = Lime)
            }
            Spacer(Modifier.width(8.dp))
            Text(
                "MESHDROP",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W700,
                    fontSize = 11.sp, letterSpacing = 1.4.sp, color = Color(0xCCFFFFFF),
                ),
            )
            Spacer(Modifier.weight(1f))
            Text(
                "now · 192.168.1.31",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = Color(0x99FFFFFF),
                ),
            )
        }
        // 标题 + 副标题
        Text(
            text = "嘉伟 发来文件",
            style = TextStyle(
                fontFamily = Geist, fontWeight = FontWeight.W700,
                fontSize = 15.sp, color = Color.White,
            ),
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            FileGlyph(ext = "pages", sizeDp = 34.dp)
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "规划文档_v0.3.pages",
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W600,
                        fontSize = 14.sp, color = Color.White,
                    ),
                )
                Text(
                    "3.4 MB · Jiawei · iPad",
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = Color(0xB3FFFFFF),
                    ),
                )
            }
        }

        if (expanded) {
            Spacer(Modifier.height(2.dp))
            Box(
                Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color(0xFF1E1E1E))
                    .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp))
                    .fillMaxWidth(),
            ) {
                Text(
                    text = "“改完了帮我看下第二章，特别是 §2.3 那段”",
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W400,
                        fontSize = 13.sp, color = Color(0xE6FFFFFF),
                    ),
                )
            }
        }

        // 三个 action 按钮（圆胶囊）
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
        ) {
            NotifAction(label = stringResource(R.string.headsup_accept), primary = true, modifier = Modifier.weight(1f))
            NotifAction(label = stringResource(R.string.headsup_reject), primary = false, modifier = Modifier.weight(1f))
            NotifAction(label = stringResource(R.string.headsup_to_photos), primary = false, modifier = Modifier.weight(1.4f))
        }
    }
}

@Composable
private fun NotifAction(label: String, primary: Boolean, modifier: Modifier = Modifier) {
    val bg = if (primary) Lime else Color(0xFF3D3D3D)
    val fg = if (primary) Ink else Color.White
    Box(
        modifier = modifier
            .height(34.dp)
            .clip(RoundedCornerShape(17.dp))
            .background(bg),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = TextStyle(
                fontFamily = Geist, fontWeight = FontWeight.W700,
                fontSize = 13.sp, color = fg,
            ),
        )
    }
}
