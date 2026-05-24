package com.welape.meshdrop.bridge

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.Wearable
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.TimeUnit

private const val TAG = "WearAssetTransfer"

/**
 * companion-bridges.md §4.2 大文件：wear 端用 `DataClient.putDataItem(...)`
 * 上传到 path `/meshdrop/files/<id>`，phone 端拿到 dataItem.uri 后把内容写到本地缓存，
 * 再用 Uri 交给 ShareEngine.sendFile()。
 *
 * 抓本地缓存写入只是为了能复用现有 ShareEngine.sendFile(Uri) 入口；不上 disk 就要重写
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
            val data = item.data ?: run {
                dataItems.release()
                Log.w(TAG, "data item empty at $fileRef")
                return null
            }
            val cacheDir = File(context.cacheDir, "wear-incoming").apply { mkdirs() }
            val dst = File(cacheDir, suggestedName.ifBlank { "wear-${System.currentTimeMillis()}.bin" })
            FileOutputStream(dst).use { it.write(data) }
            dataItems.release()
            Uri.fromFile(dst)
        } catch (e: Exception) {
            Log.e(TAG, "fetchAssetToLocal failed for $fileRef", e)
            null
        }
    }
}
