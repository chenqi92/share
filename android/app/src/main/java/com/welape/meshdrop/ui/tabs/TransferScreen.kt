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
import androidx.compose.material3.Text
import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.welape.meshdrop.R
import androidx.core.content.FileProvider
import java.io.File
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.data.HistoryItem
import com.welape.meshdrop.data.HistoryKind
import com.welape.meshdrop.data.TransferDirection
import com.welape.meshdrop.data.TransferMetrics
import com.welape.meshdrop.data.TransferStatus
import com.welape.meshdrop.mock.MockDownloadBars
import com.welape.meshdrop.mock.MockSessionBars
import com.welape.meshdrop.mock.MockTransfer
import com.welape.meshdrop.mock.MockTransfers
import com.welape.meshdrop.mock.MockUploadBars
import com.welape.meshdrop.mock.TransferState
import com.welape.meshdrop.transport.ShareEngine
import java.util.Locale
import java.util.UUID
import kotlin.math.roundToInt
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
fun TransferScreen(engine: ShareEngine? = null) {
    if (engine == null) {
        TransferScreenContent(
            transfers = MockTransfers,
            onCancel = {},
            onRetry = {},
            sessionTotalBytes = 0L,
            currentUploadBps = 0.0,
            currentDownloadBps = 0.0,
        )
        return
    }
    val history by engine.history.collectAsState()
    val metrics by engine.transferMetrics.collectAsState()
    val throughput by engine.sessionThroughput.collectAsState()
    // 方向标签「我」与取消原因文案要随 locale 切换，从资源取值后透传给纯函数映射。
    val meLabel = stringResource(R.string.transfer_me)
    val canceledLabel = stringResource(R.string.transfer_canceled)
    val transfers = history.mapNotNull { it.toDisplayTransfer(metrics[it.id], meLabel, canceledLabel) }

    // 会话汇总：所有文件历史 size 之和；瞬时速率分方向求和。
    val sessionTotal = history.sumOf {
        (it.kind as? HistoryKind.File)?.size ?: 0L
    }
    val (up, down) = history.fold(0.0 to 0.0) { acc, h ->
        if (h.status is TransferStatus.Transferring) {
            val m = metrics[h.id]?.bytesPerSec ?: 0.0
            if (h.direction == TransferDirection.OUTGOING) acc.first + m to acc.second
            else acc.first to acc.second + m
        } else acc
    }

    TransferScreenContent(
        transfers = transfers,
        onCancel = { t ->
            runCatching { UUID.fromString(t.id) }.getOrNull()?.let { engine.cancelTransfer(it) }
        },
        onRetry = { t ->
            runCatching { UUID.fromString(t.id) }.getOrNull()?.let { engine.retryTransfer(it) }
        },
        sessionTotalBytes = sessionTotal,
        currentUploadBps = up,
        currentDownloadBps = down,
        upBars = throughput.up.map { it.roundToInt() },
        downBars = throughput.down.map { it.roundToInt() },
    )
}

@Composable
private fun TransferScreenContent(
    transfers: List<MockTransfer>,
    onCancel: (MockTransfer) -> Unit,
    onRetry: (MockTransfer) -> Unit,
    sessionTotalBytes: Long,
    currentUploadBps: Double,
    currentDownloadBps: Double,
    upBars: List<Int> = emptyList(),
    downBars: List<Int> = emptyList(),
) {
    val mesh = MeshTheme.colors
    val meLabel = stringResource(R.string.transfer_me)
    val inProgress = transfers.filter { it.state == TransferState.SENDING || it.state == TransferState.RECEIVING }
    val completed = transfers.filter { it.state == TransferState.DONE }
    val queued = transfers.filter { it.state == TransferState.QUEUED }
    // 仅显示「本机发起」的失败项可重试；from 标签由 toDisplayTransfer 用同一资源串填充。
    val failed = transfers.filter { it.state == TransferState.FAILED && it.from == meLabel }

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
                    text = stringResource(R.string.transfer_title),
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 28.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
                    ),
                )
                Text(
                    text = stringResource(R.string.transfer_subtitle, inProgress.size, completed.size, queued.size),
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = mesh.textTertiary,
                    ),
                )
            }
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
                MonoLabel(stringResource(R.string.transfer_session_label))
                Spacer(Modifier.weight(1f))
                MeshChip(text = "LIVE", tone = ChipTone.LIME, mono = true)
            }

            Spacer(Modifier.height(10.dp))

            val (sessionNum, sessionUnit) = formatSessionTotal(sessionTotalBytes)
            Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = sessionNum,
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 44.sp, color = LimeDeep, letterSpacing = (-1).sp,
                    ),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    text = stringResource(R.string.transfer_session_transferred, sessionUnit),
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 14.sp, color = mesh.textTertiary,
                    ),
                    modifier = Modifier.padding(bottom = 8.dp),
                )
            }
            Spacer(Modifier.height(6.dp))

            SpeedChart(
                upBars = upBars.ifEmpty { MockUploadBars },
                downBars = downBars.ifEmpty { MockDownloadBars },
                height = 88.dp,
            )

            Spacer(Modifier.height(10.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                MetricStat(label = stringResource(R.string.transfer_metric_up), value = formatBps(currentUploadBps), color = Flame)
                MetricStat(label = stringResource(R.string.transfer_metric_down), value = formatBps(currentDownloadBps), color = Sky)
                MetricStat(label = stringResource(R.string.transfer_metric_active), value = "${inProgress.size}", color = LimeDeep)
            }
        }

        Spacer(Modifier.height(8.dp))
        AsciiDivider(label = stringResource(R.string.transfer_section_in_progress, inProgress.size))

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            inProgress.forEach { TransferRow(item = it, onCancel = { onCancel(it) }) }
        }

        Spacer(Modifier.height(4.dp))
        AsciiDivider(label = stringResource(R.string.transfer_section_completed, completed.size))

        val context = LocalContext.current
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            completed.forEach { item ->
                val onOpen = item.savedFileUri?.let { uriStr ->
                    { openReceivedFile(context, uriStr) }
                }
                TransferRow(item = item, onOpen = onOpen)
            }
        }

        if (queued.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            AsciiDivider(label = stringResource(R.string.transfer_section_queued, queued.size))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                queued.forEach { TransferRow(item = it) }
            }
        }

        if (failed.isNotEmpty()) {
            Spacer(Modifier.height(4.dp))
            AsciiDivider(label = stringResource(R.string.transfer_section_failed, failed.size))
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                failed.forEach { TransferRow(item = it, onRetry = { onRetry(it) }) }
            }
        }

        Spacer(Modifier.height(80.dp))
    }
}

/**
 * HistoryItem → MockTransfer：仅文件项参与传输面板；text 历史返回 null。
 * meLabel/canceledLabel 由调用方从资源取出后传入，避免在纯函数里依赖 Context。
 */
private fun HistoryItem.toDisplayTransfer(
    metrics: TransferMetrics? = null,
    meLabel: String,
    canceledLabel: String,
): MockTransfer? {
    val file = kind as? HistoryKind.File ?: return null
    val sizeLabel = humanSize(file.size)
    val ext = file.name.substringAfterLast('.', "bin").lowercase()
    val (progress, state) = when (val s = status) {
        is TransferStatus.Transferring -> {
            val pct = if (s.bytesTotal > 0) ((s.bytesDone * 100) / s.bytesTotal).toInt() else 0
            pct to if (direction == TransferDirection.OUTGOING) TransferState.SENDING else TransferState.RECEIVING
        }
        TransferStatus.Completed -> 100 to TransferState.DONE
        is TransferStatus.Pending, TransferStatus.WaitingApproval -> 0 to TransferState.QUEUED
        is TransferStatus.Failed, TransferStatus.Canceled -> 0 to TransferState.FAILED
    }
    val peerLabel = peer.name.ifBlank { peer.model ?: peer.id.take(8) }
    val from = if (direction == TransferDirection.OUTGOING) meLabel else peerLabel
    val to = if (direction == TransferDirection.OUTGOING) peerLabel else meLabel
    val active = state == TransferState.SENDING || state == TransferState.RECEIVING
    val speed = if (active && metrics != null && metrics.bytesPerSec > 1.0) formatSpeed(metrics.bytesPerSec) else null
    val eta = if (active) metrics?.etaSeconds?.let(::formatEta) else null
    val savedUri = if (state == TransferState.DONE && direction == TransferDirection.INCOMING) {
        file.uri?.toString()
    } else null
    val failReason = when (val s = status) {
        is TransferStatus.Failed -> s.reason
        TransferStatus.Canceled -> canceledLabel
        else -> null
    }
    return MockTransfer(
        id = id.toString(),
        name = file.name,
        size = sizeLabel,
        ext = ext,
        from = from,
        to = to,
        progress = progress,
        state = state,
        speed = speed,
        eta = eta,
        savedFileUri = savedUri,
        failReason = failReason,
    )
}

/**
 * 用 ACTION_VIEW 让系统选默认应用打开文件。原始 file:// 在 Android 7+ 上会触发
 * FileUriExposedException，所以走 FileProvider 给系统颁发临时 content:// 授权。
 */
private fun openReceivedFile(context: android.content.Context, fileUriStr: String) {
    val raw = Uri.parse(fileUriStr)
    val path = raw.path ?: return
    val file = File(path)
    if (!file.exists()) return
    val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(
        file.extension.lowercase(Locale.US)
    ) ?: "*/*"
    val authority = "${context.packageName}.fileprovider"
    val shareUri = try {
        FileProvider.getUriForFile(context, authority, file)
    } catch (_: IllegalArgumentException) {
        // 路径不在 file_provider_paths 白名单里 — 落到 raw uri 让系统报错可见
        raw
    }
    val intent = Intent(Intent.ACTION_VIEW).apply {
        setDataAndType(shareUri, mime)
        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
    try {
        context.startActivity(intent)
    } catch (_: android.content.ActivityNotFoundException) {
        // 系统找不到任何应用能打开这个 MIME — 静默
    }
}

private fun formatSpeed(bps: Double): String {
    if (bps < 1024) return String.format(Locale.US, "%.0f B/s", bps)
    if (bps < 1024 * 1024) return String.format(Locale.US, "%.1f KB/s", bps / 1024.0)
    return String.format(Locale.US, "%.1f MB/s", bps / 1024.0 / 1024.0)
}

/** SESSION 卡顶部「上行 ↑ / 下行 ↓」MetricStat 用：0 时显示 "—"。 */
private fun formatBps(bps: Double): String = if (bps > 1.0) formatSpeed(bps) else "—"

/** SESSION 卡大数字：拆 (num, unit) 给 UI 分字号渲染。 */
private fun formatSessionTotal(bytes: Long): Pair<String, String> {
    if (bytes <= 0) return "0" to "B"
    val kb = bytes / 1024.0
    if (kb < 1024) return String.format(Locale.US, "%.1f", kb) to "KB"
    val mb = kb / 1024.0
    if (mb < 1024) return String.format(Locale.US, "%.1f", mb) to "MB"
    val gb = mb / 1024.0
    return String.format(Locale.US, "%.2f", gb) to "GB"
}

private fun formatEta(secs: Double): String {
    if (!secs.isFinite() || secs < 0) return "—"
    if (secs < 1) return "<1s"
    if (secs >= 3600) return ">1h"
    val s = secs.toInt()
    return String.format(Locale.US, "%02d:%02d", s / 60, s % 60)
}

private fun humanSize(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val kb = bytes / 1024.0
    if (kb < 1024) return String.format(Locale.US, "%.1f KB", kb)
    val mb = kb / 1024.0
    if (mb < 1024) return String.format(Locale.US, "%.1f MB", mb)
    val gb = mb / 1024.0
    return String.format(Locale.US, "%.1f GB", gb)
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
