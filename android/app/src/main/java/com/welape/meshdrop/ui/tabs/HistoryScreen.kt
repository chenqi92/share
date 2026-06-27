package com.welape.meshdrop.ui.tabs

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import com.welape.meshdrop.R
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.HistoryDir
import com.welape.meshdrop.mock.HistoryKindMock
import com.welape.meshdrop.mock.HistoryStatus
import com.welape.meshdrop.mock.MockHistory
import com.welape.meshdrop.mock.MockHistoryItem
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.FileGlyph
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.Photo
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@Composable
fun HistoryScreen(items: List<MockHistoryItem> = MockHistory, onOpen: (String) -> Unit = {}) {
    val mesh = MeshTheme.colors
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(mesh.canvas)
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(horizontal = 20.dp)),
    ) {
        Spacer(Modifier.height(20.dp))
        Column {
            Text(
                text = stringResource(R.string.history_title),
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 28.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
                ),
            )
            Text(
                text = stringResource(R.string.history_subtitle, items.size),
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 11.sp, color = mesh.textTertiary,
                ),
            )
        }

        Spacer(Modifier.height(14.dp))

        // 类型 chips
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            MeshChip(text = stringResource(R.string.history_filter_all), tone = ChipTone.INK)
            MeshChip(text = stringResource(R.string.history_filter_image), tone = ChipTone.OUTLINE)
            MeshChip(text = stringResource(R.string.history_filter_file), tone = ChipTone.OUTLINE)
            MeshChip(text = stringResource(R.string.history_filter_text), tone = ChipTone.OUTLINE)
        }

        AsciiDivider(label = stringResource(R.string.history_section_today, items.size))

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items.forEach { item -> HistoryRow(item, onOpen) }
        }

        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun HistoryRow(item: MockHistoryItem, onOpen: (String) -> Unit = {}) {
    val mesh = MeshTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, mesh.outline, RoundedCornerShape(14.dp))
            .background(mesh.card)
            .clickable(enabled = item.peerKey.isNotBlank()) { onOpen(item.peerKey) }
            .padding(PaddingValues(horizontal = 12.dp, vertical = 12.dp)),
        verticalAlignment = Alignment.Top,
    ) {
        // 方向 + 类型 icon
        Column(modifier = Modifier.width(44.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            val arrowColor = if (item.dir == HistoryDir.OUTGOING) mesh.flame else mesh.sky
            val arrow = if (item.dir == HistoryDir.OUTGOING) "↑" else "↓"
            Box(
                Modifier
                    .size(28.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(arrowColor.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    arrow,
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W700,
                        fontSize = 14.sp, color = arrowColor,
                    ),
                )
            }
            Spacer(Modifier.height(4.dp))
            Text(
                item.time,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = mesh.textTertiary,
                ),
            )
        }
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = item.peer,
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W700,
                        fontSize = 13.sp, color = mesh.textPrimary,
                    ),
                )
                Spacer(Modifier.width(6.dp))
                StatusBadge(item.status)
            }
            Spacer(Modifier.height(6.dp))
            when (val k = item.kind) {
                is HistoryKindMock.Text -> Text(
                    text = "\"${k.content}\"",
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W400,
                        fontSize = 13.sp, color = mesh.textSecondary,
                    ),
                    maxLines = 2, overflow = TextOverflow.Ellipsis,
                )
                is HistoryKindMock.Image -> Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Photo(sizeDp = 64.dp, hueDeg = 22, corner = 10.dp)
                    Photo(sizeDp = 64.dp, hueDeg = 198, corner = 10.dp)
                    Column(modifier = Modifier.padding(start = 4.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(
                            stringResource(R.string.history_photo_count, k.count),
                            style = TextStyle(fontFamily = Geist, fontWeight = FontWeight.W600, fontSize = 12.sp, color = mesh.textPrimary),
                        )
                        Text(
                            stringResource(R.string.history_saved_to),
                            style = TextStyle(fontFamily = GeistMono, fontSize = 10.sp, color = mesh.textTertiary),
                        )
                    }
                }
                is HistoryKindMock.File -> Row(verticalAlignment = Alignment.CenterVertically) {
                    FileGlyph(ext = k.ext, sizeDp = 34.dp)
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = k.name,
                            style = TextStyle(
                                fontFamily = Geist, fontWeight = FontWeight.W600,
                                fontSize = 13.sp, color = mesh.textPrimary,
                            ),
                            maxLines = 1, overflow = TextOverflow.Ellipsis,
                        )
                        Text(
                            text = if (k.progress != null) "${k.size} · ${k.progress}%" else k.size,
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                                fontSize = 10.sp, color = mesh.textTertiary,
                            ),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StatusBadge(status: HistoryStatus) {
    val (label, tone) = when (status) {
        HistoryStatus.DONE -> "DONE" to ChipTone.LIME
        HistoryStatus.TRANSFERRING -> "ACTIVE" to ChipTone.FLAME
        HistoryStatus.QUEUED -> "QUEUED" to ChipTone.OUTLINE
        HistoryStatus.FAILED -> "FAILED" to ChipTone.FLAME
    }
    MeshChip(text = label, tone = tone, mono = true)
}
