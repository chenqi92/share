package drop.mesh.ui

import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.NoteAdd
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import drop.mesh.data.Device
import drop.mesh.data.formatBytes

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SendSheet(device: Device, onDismiss: () -> Unit) {
    val engine = LocalEngine.current
    val context = LocalContext.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)

    var mode by remember { mutableStateOf(0) }   // 0=文本 1=文件
    var text by remember { mutableStateOf("") }
    var fileUri by remember { mutableStateOf<Uri?>(null) }
    var fileName by remember { mutableStateOf("") }
    var fileSize by remember { mutableStateOf(0L) }

    val filePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) {
            // 持久化授权
            try {
                context.contentResolver.takePersistableUriPermission(
                    uri, android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                )
            } catch (_: Exception) {}
            fileUri = uri
            context.contentResolver.query(uri, null, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val nameIdx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIdx = c.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIdx >= 0) fileName = c.getString(nameIdx)
                    if (sizeIdx >= 0) fileSize = c.getLong(sizeIdx)
                }
            }
        }
    }

    val canSend = (mode == 0 && text.isNotBlank()) || (mode == 1 && fileUri != null)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            // Header
            Row(verticalAlignment = Alignment.CenterVertically) {
                OsBadge(device.os, size = 36)
                Spacer(Modifier.width(12.dp))
                Column {
                    Text(
                        "发送到 ${device.name}",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                    )
                    Text(
                        device.humanFingerprint,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        fontFamily = FontFamily.Monospace,
                    )
                }
            }

            // Mode picker
            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                listOf("文本", "文件").forEachIndexed { idx, label ->
                    SegmentedButton(
                        selected = mode == idx,
                        onClick = { mode = idx },
                        shape = SegmentedButtonDefaults.itemShape(index = idx, count = 2),
                    ) { Text(label) }
                }
            }

            // Content area
            when (mode) {
                0 -> Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(160.dp),
                    shape = RoundedCornerShape(14.dp),
                    color = MaterialTheme.colorScheme.surfaceContainer,
                ) {
                    BasicTextField(
                        value = text,
                        onValueChange = { text = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        textStyle = MaterialTheme.typography.bodyLarge.copy(
                            color = MaterialTheme.colorScheme.onSurface
                        ),
                        cursorBrush = androidx.compose.ui.graphics.SolidColor(MaterialTheme.colorScheme.primary),
                    )
                }

                1 -> if (fileUri != null) {
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(14.dp),
                        color = MaterialTheme.colorScheme.surfaceContainer,
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Icon(
                                Icons.Filled.Description,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(28.dp),
                            )
                            Spacer(Modifier.width(12.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Text(fileName, style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium), maxLines = 1)
                                Text(formatBytes(fileSize), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                            TextButton(onClick = { filePicker.launch(arrayOf("*/*")) }) { Text("更换") }
                        }
                    }
                } else {
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(160.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(MaterialTheme.colorScheme.surfaceContainerLow),
                        color = Color.Transparent,
                        onClick = { filePicker.launch(arrayOf("*/*")) },
                    ) {
                        Column(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center,
                        ) {
                            Icon(
                                Icons.Filled.NoteAdd,
                                contentDescription = null,
                                modifier = Modifier.size(40.dp),
                                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                            )
                            Spacer(Modifier.height(8.dp))
                            Text(
                                "选择文件",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }

            // 按钮区
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
            ) {
                TextButton(onClick = onDismiss) { Text("取消") }
                Spacer(Modifier.width(8.dp))
                Button(
                    onClick = {
                        if (mode == 0) {
                            engine.sendText(device, text)
                        } else {
                            fileUri?.let { engine.sendFile(device, it, fileName, fileSize) }
                        }
                        onDismiss()
                    },
                    enabled = canSend,
                ) { Text("发送") }
            }
        }
    }
}
