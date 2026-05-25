package com.welape.meshdrop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.welape.meshdrop.PendingShare
import com.welape.meshdrop.ShareApplication
import com.welape.meshdrop.transport.ShareEngine

/**
 * 外部应用 share 给 MeshDrop 后，主 Activity 把内容存进 [ShareApplication.pendingShare]。
 * 这个 sheet 监听 pendingShare，非空时全屏覆盖出来，列出在线设备让用户选目标。
 * 选完后调 [ShareEngine.sendText] / [ShareEngine.sendFile] 真发出去，并清空 pendingShare。
 */
@Composable
fun PendingShareOverlay(engine: ShareEngine) {
    val ctx = LocalContext.current
    val app = remember(ctx) { ctx.applicationContext as? ShareApplication } ?: return
    val pending by app.pendingShare.collectAsState()
    val devices by engine.devices.collectAsState()

    val current = pending ?: return

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xCC0E0C09))
            .clickable { app.consumePendingShare() },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .padding(24.dp)
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(16.dp))
                .clickable(enabled = false) { /* 阻止点击穿透关闭 */ }
                .padding(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = when (current) {
                        is PendingShare.Text -> "把这段文字发给…"
                        is PendingShare.Files -> "把这 ${current.uris.size} 个文件发给…"
                    },
                    style = MaterialTheme.typography.titleMedium,
                )
                Text(
                    text = when (current) {
                        is PendingShare.Text -> current.content.take(140)
                        is PendingShare.Files -> current.uris.joinToString { it.lastPathSegment ?: "file" }
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                )
                LazyColumn(
                    contentPadding = PaddingValues(vertical = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(devices) { device ->
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    MaterialTheme.colorScheme.surfaceVariant,
                                    RoundedCornerShape(10.dp),
                                )
                                .clickable {
                                    val share = app.consumePendingShare() ?: return@clickable
                                    when (share) {
                                        is PendingShare.Text -> engine.sendText(device, share.content)
                                        is PendingShare.Files -> {
                                            share.uris.forEach { uri ->
                                                val (name, size) = resolveUri(ctx, uri)
                                                engine.sendFile(device, uri, name, size)
                                            }
                                        }
                                    }
                                }
                                .padding(12.dp),
                        ) {
                            Text(text = device.name, style = MaterialTheme.typography.bodyMedium)
                        }
                    }
                }
            }
        }
    }
}

private fun resolveUri(ctx: android.content.Context, uri: android.net.Uri): Pair<String, Long> {
    var name = uri.lastPathSegment ?: "file"
    var size = 0L
    runCatching {
        ctx.contentResolver.query(uri, null, null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                val nameIdx = c.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                val sizeIdx = c.getColumnIndex(android.provider.OpenableColumns.SIZE)
                if (nameIdx >= 0) name = c.getString(nameIdx) ?: name
                if (sizeIdx >= 0) size = c.getLong(sizeIdx)
            }
        }
    }
    return name to size
}
