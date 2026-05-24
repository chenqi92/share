package com.welape.meshdrop.ui.tabs

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.MoreHoriz
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockDownloadBars
import com.welape.meshdrop.mock.MockSessionBars
import com.welape.meshdrop.mock.MockTransfers
import com.welape.meshdrop.mock.MockUploadBars
import com.welape.meshdrop.mock.TransferState
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.MeshIconBtn
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.components.SpeedChart
import com.welape.meshdrop.ui.components.StateDotChip
import com.welape.meshdrop.ui.components.TransferRow
import com.welape.meshdrop.ui.theme.Flame
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.Sky
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@Composable
fun TransferScreen() {
    val mesh = MeshTheme.colors
    val inProgress = MockTransfers.filter { it.state == TransferState.SENDING || it.state == TransferState.RECEIVING }
    val completed = MockTransfers.filter { it.state == TransferState.DONE }
    val queued = MockTransfers.filter { it.state == TransferState.QUEUED }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(mesh.canvas)
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(horizontal = 20.dp)),
    ) {
        Spacer(Modifier.height(20.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column {
                Text(
                    text = "传输 · Transfers",
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 28.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
                    ),
                )
                Text(
                    text = "${inProgress.size} 活跃 · ${completed.size} 完成 · ${queued.size} 排队",
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = mesh.textTertiary,
                    ),
                )
            }
            Spacer(Modifier.weight(1f))
            MeshIconBtn(icon = Icons.Outlined.MoreHoriz, contentDescription = "更多", bordered = true, sizeDp = 36.dp)
        }

        Spacer(Modifier.height(16.dp))

        // SESSION 卡
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .border(1.dp, mesh.outline, RoundedCornerShape(18.dp))
                .background(mesh.card)
                .padding(PaddingValues(horizontal = 18.dp, vertical = 18.dp)),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                MonoLabel("本会话 · SESSION")
                Spacer(Modifier.weight(1f))
                MeshChip(text = "LIVE", tone = ChipTone.LIME, mono = true)
            }

            Spacer(Modifier.height(10.dp))

            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = "1.24",
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 44.sp, color = LimeDeep, letterSpacing = (-1).sp,
                    ),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = "GB sent",
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 14.sp, color = mesh.textTertiary,
                    ),
                    modifier = Modifier.padding(bottom = 8.dp),
                )
            }
            Spacer(Modifier.height(6.dp))

            SpeedChart(upBars = MockUploadBars, downBars = MockDownloadBars, height = 88.dp)

            Spacer(Modifier.height(10.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                MetricStat(label = "上行 ↑", value = "8.4 MB/s", color = Flame)
                MetricStat(label = "下行 ↓", value = "11.7 MB/s", color = Sky)
                MetricStat(label = "活跃任务", value = "${inProgress.size}", color = LimeDeep)
            }
        }

        Spacer(Modifier.height(8.dp))
        AsciiDivider(label = "进行中 · IN PROGRESS · ${inProgress.size}")

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            inProgress.forEach { TransferRow(item = it) }
        }

        Spacer(Modifier.height(4.dp))
        AsciiDivider(label = "已完成 · COMPLETED · 今天 · ${completed.size}")

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            completed.forEach { TransferRow(item = it) }
        }

        if (queued.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            AsciiDivider(label = "排队中 · QUEUED · ${queued.size}")
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                queued.forEach { TransferRow(item = it) }
            }
        }

        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun MetricStat(label: String, value: String, color: androidx.compose.ui.graphics.Color) {
    val mesh = MeshTheme.colors
    Column {
        Text(
            label,
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W700,
                fontSize = 10.sp, letterSpacing = 1.4.sp, color = mesh.textTertiary,
            ),
        )
        Spacer(Modifier.height(2.dp))
        Text(
            value,
            style = TextStyle(
                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                fontSize = 18.sp, color = color, letterSpacing = (-0.3).sp,
            ),
        )
    }
}
