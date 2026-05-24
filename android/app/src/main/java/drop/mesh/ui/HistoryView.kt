package drop.mesh.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.outlined.DeleteOutline
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import drop.mesh.data.HistoryItem
import drop.mesh.data.HistoryKind
import drop.mesh.data.TransferDirection
import drop.mesh.data.TransferStatus
import drop.mesh.data.formatBytes

@Composable
fun HistoryView() {
    val engine = LocalEngine.current
    val history by engine.history.collectAsState()

    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceContainer,
        tonalElevation = 2.dp,
        shadowElevation = 4.dp,
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(Icons.Filled.History, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.width(8.dp))
                Text("历史", style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold))
                Spacer(Modifier.width(6.dp))
                Surface(
                    shape = RoundedCornerShape(10.dp),
                    color = MaterialTheme.colorScheme.primary.copy(alpha = 0.15f),
                ) {
                    Text(
                        "${history.size}",
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
                Spacer(Modifier.weight(1f))
                IconButton(onClick = engine::clearHistory) {
                    Icon(Icons.Outlined.DeleteOutline, contentDescription = "清空")
                }
            }
            HorizontalDivider()

            LazyColumn(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(max = 280.dp)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                items(history, key = { it.id }) { item ->
                    HistoryRow(item = item)
                }
            }
        }
    }
}

@Composable
private fun HistoryRow(item: HistoryItem) {
    val engine = LocalEngine.current
    var menuExpanded by remember { mutableStateOf(false) }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(10.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
    ) {
        Row(
            modifier = Modifier.padding(10.dp),
            verticalAlignment = Alignment.Top,
        ) {
            val isOut = item.direction == TransferDirection.OUTGOING
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(CircleShape)
                    .background(
                        if (isOut) MaterialTheme.colorScheme.primary.copy(alpha = 0.15f)
                        else Color(0xFF22C55E).copy(alpha = 0.15f)
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = if (isOut) Icons.Filled.ArrowUpward else Icons.Filled.ArrowDownward,
                    contentDescription = null,
                    tint = if (isOut) MaterialTheme.colorScheme.primary else Color(0xFF22C55E),
                    modifier = Modifier.size(14.dp),
                )
            }
            Spacer(Modifier.width(10.dp))

            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        if (isOut) "发送到" else "来自",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.width(4.dp))
                    Text(
                        item.peer.name,
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                    )
                }

                // 内容
                when (val k = item.kind) {
                    is HistoryKind.Text -> Text(
                        k.content,
                        style = MaterialTheme.typography.bodyMedium,
                        maxLines = 6,
                    )
                    is HistoryKind.File -> Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.Description, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(6.dp))
                        Column {
                            Text(k.name, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium))
                            Text(formatBytes(k.size), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }

                // 状态
                StatusLine(status = item.status)
            }

            // 操作按钮
            Box {
                IconButton(onClick = { menuExpanded = true }, modifier = Modifier.size(28.dp)) {
                    Icon(Icons.Filled.MoreHoriz, contentDescription = "操作", modifier = Modifier.size(16.dp))
                }
                DropdownMenu(expanded = menuExpanded, onDismissRequest = { menuExpanded = false }) {
                    DropdownMenuItem(
                        text = { Text("删除") },
                        onClick = {
                            engine.removeHistoryItem(item.id)
                            menuExpanded = false
                        },
                        leadingIcon = { Icon(Icons.Outlined.DeleteOutline, contentDescription = null) },
                    )
                }
            }
        }
    }
}

@Composable
private fun StatusLine(status: TransferStatus) {
    when (status) {
        TransferStatus.Pending, TransferStatus.WaitingApproval -> {
            Text(
                if (status == TransferStatus.Pending) "准备中…" else "等待对方接受…",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        is TransferStatus.Transferring -> {
            Column {
                LinearProgressIndicator(
                    progress = {
                        if (status.bytesTotal > 0) (status.bytesDone.toFloat() / status.bytesTotal) else 0f
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(3.dp),
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    "${formatBytes(status.bytesDone)} / ${formatBytes(status.bytesTotal)}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        TransferStatus.Completed -> Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.CheckCircle, contentDescription = null, tint = Color(0xFF22C55E), modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(4.dp))
            Text("完成", style = MaterialTheme.typography.labelSmall, color = Color(0xFF22C55E))
        }
        is TransferStatus.Failed -> Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.Error, contentDescription = null, tint = MaterialTheme.colorScheme.error, modifier = Modifier.size(12.dp))
            Spacer(Modifier.width(4.dp))
            Text(status.reason, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.error)
        }
        TransferStatus.Canceled -> Text("已取消", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
