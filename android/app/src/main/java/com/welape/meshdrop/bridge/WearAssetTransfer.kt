package com.welape.meshdrop.bridge

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

private const val TAG = "WearAssetTransfer"

/**
 * companion-bridges.md §4.2 大文件：wear 端用 `DataClient.putDataItem(...)` 把文件作为
 * `putAsset("file", asset)` 上传到 path `/meshdrop/files/<id>`；phone 端按 `send_file_ref`
 * 给的完整 path 解析 DataItem，从 DataMap 取出 Asset、用 `getFdForAsset` 拉字节落到本地缓存，
 * 再用 Uri 交给 ShareEngine.sendFile()。
 *
 * 落本地缓存只是为了能复用现有 ShareEngine.sendFile(Uri) 入口；不上 disk 就要重写
 * Engine 接受 InputStream 的能力，超本轮范围。
 */
class WearAssetTransfer(private val context: Context) {

    private val dataClient: DataClient by lazy { Wearable.getDataClient(context) }

    /**
     * 把 wear 上传的 asset 拉下来落到 cache，返回本地 Uri。
     *
     * @param fileRef wear 端给的 path（形如 "/meshdrop/files/<id>"）
     * @param suggestedName 文件名（落盘用，不要求唯一）
     */
    fun fetchAssetToLocal(fileRef: String, suggestedName: String): Uri? {
        return try {
            val dataItems = Tasks.await(
                dataClient.getDataItems(Uri.parse("wear:$fileRef")),
                15, TimeUnit.SECONDS,
            )
            val item = dataItems.firstOrNull() ?: run {
                dataItems.release()
                Log.w(TAG, "no data items at $fileRef")
                return null
            }
            // wear 端用 putAsset("file", asset) 写入；大文件内容只在 Asset 里，不在 dataItem.data。
            // 必须经 DataMap.getAsset 取出 Asset 再 getFdForAsset 拉字节，直接读 item.data 会得到损坏/空文件。
            val asset = DataMapItem.fromDataItem(item).dataMap.getAsset("file") ?: run {
                dataItems.release()
                Log.w(TAG, "no \"file\" asset at $fileRef")
                return null
            }
            // dataItems 持有的是元数据句柄，asset 已是独立引用，可在拉取前释放。
            dataItems.release()
            val fdResponse = Tasks.await(dataClient.getFdForAsset(asset), 15, TimeUnit.SECONDS)
            val input = fdResponse?.inputStream ?: run {
                fdResponse?.release()
                Log.w(TAG, "asset fd null at $fileRef")
                return null
            }
            val cacheDir = File(context.cacheDir, "wear-incoming").apply { mkdirs() }
            val dst = File(cacheDir, suggestedName.ifBlank { "wear-${System.currentTimeMillis()}.bin" })
            input.use { src -> FileOutputStream(dst).use { src.copyTo(it) } }
            fdResponse.release()
            Uri.fromFile(dst)
        } catch (e: Exception) {
            Log.e(TAG, "fetchAssetToLocal failed for $fileRef", e)
            null
        }
    }
}
