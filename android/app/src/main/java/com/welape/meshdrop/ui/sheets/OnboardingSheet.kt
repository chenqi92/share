package com.welape.meshdrop.ui.sheets

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.ui.components.MeshDropLockup
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

data class OnboardStep(val tag: String, val title: String, val body: String)

private val Steps = listOf(
    OnboardStep("STEP 1 · DISCOVERY", "雷达式发现", "本机会自动注册到局域网，扫描同 Wi-Fi 下的其他 MeshDrop 设备。雷达图实时显示 RTT 和方位。"),
    OnboardStep("STEP 2 · DRAG-TO-SEND", "拖即发送", "把文件拖到设备 row 上，或长按选多台。也支持 Android 原生 Share Intent。"),
    OnboardStep("STEP 3 · E2E", "端到端加密", "X25519 握手 + ChaCha20-Poly1305，配对后双方信任互相指纹。首次连接会弹 6 字符确认。"),
    OnboardStep("STEP 4 · SHORTCUTS", "通知 / 后台 / 系统分享", "大文件用 Foreground Service 保活，incoming 弹 heads-up 通知，三键操作。"),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingSheet(onClose: () -> Unit) {
    val mesh = MeshTheme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
        containerColor = mesh.card,
        contentColor = mesh.textPrimary,
    ) {
        OnboardingSheetContent(onClose = onClose)
    }
}

@Composable
fun OnboardingSheetContent(onClose: () -> Unit = {}) {
    val mesh = MeshTheme.colors
    var idx by remember { mutableStateOf(0) }
    val step = Steps[idx]
    Column(
        modifier = Modifier
            .background(mesh.card)
            .fillMaxWidth()
            .padding(PaddingValues(horizontal = 22.dp, vertical = 24.dp)),
    ) {
            MeshDropLockup(markSize = 26.dp, fontSize = 20.sp)
            Spacer(Modifier.height(18.dp))

            MonoLabel(step.tag)
            Spacer(Modifier.height(8.dp))
            Text(
                step.title,
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 30.sp, color = mesh.textPrimary, letterSpacing = (-0.6).sp,
                ),
            )
            Spacer(Modifier.height(8.dp))
            Text(
                step.body,
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W400,
                    fontSize = 14.sp, color = mesh.textSecondary, lineHeight = 22.sp,
                ),
            )

            Spacer(Modifier.height(18.dp))

            // 进度点
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Steps.forEachIndexed { i, _ ->
                    val active = i == idx
                    Box(
                        Modifier
                            .height(6.dp)
                            .let { if (active) it.size(width = 26.dp, height = 6.dp) else it.size(width = 8.dp, height = 6.dp) }
                            .clip(RoundedCornerShape(3.dp))
                            .background(if (active) Lime else mesh.outline),
                    )
                }
            }

            Spacer(Modifier.height(18.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                Box(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .border(1.dp, mesh.outline, RoundedCornerShape(14.dp))
                        .background(Color.Transparent)
                        .clickable {
                            if (idx > 0) idx-- else onClose()
                        }
                        .padding(PaddingValues(vertical = 14.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (idx == 0) "跳过" else "上一步",
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 14.sp, color = mesh.textPrimary,
                        ),
                    )
                }
                Box(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(Lime)
                        .clickable {
                            if (idx < Steps.lastIndex) idx++ else onClose()
                        }
                        .padding(PaddingValues(vertical = 14.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (idx == Steps.lastIndex) "开始使用 →" else "下一步 →",
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 14.sp, color = Ink,
                        ),
                    )
                }
            }
            Spacer(Modifier.height(24.dp))
    }
}
