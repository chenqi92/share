package com.welape.meshdrop.bridge

import android.content.Context
import android.net.Uri
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import java.io.File
import java.util.concurrent.TimeUnit

private const val TAG = "WearAssetTransfer"

class WearAssetTransfer(private val context: Context) {
    private val dataClient: DataClient by lazy { Wearable.getDataClient(context) }

    fun fetchAssetToLocal(sourceNodeId: String, fileRef: String): File? {
        val transferId = fileRef.removePrefix(WearBridgePaths.FILES_PREFIX)
        if (fileRef == transferId || transferId.isEmpty() || '/' in transferId) return null
        val uri = Uri.Builder().scheme("wear").authority(sourceNodeId).path(fileRef).build()
        return try {
            // The command and the DataItem travel independently; the sender may have finished its local put first.
            val deadline = SystemClock.elapsedRealtime() + 30_000
            var item = Tasks.await(dataClient.getDataItem(uri), 5, TimeUnit.SECONDS)
            while (item == null && SystemClock.elapsedRealtime() < deadline) {
                Thread.sleep(250)
                item = Tasks.await(dataClient.getDataItem(uri), 5, TimeUnit.SECONDS)
            }
            val asset = item?.let { DataMapItem.fromDataItem(it).dataMap.getAsset("file") } ?: return null
            val response = Tasks.await(dataClient.getFdForAsset(asset), 30, TimeUnit.SECONDS)
            try {
                response.inputStream.use { src ->
                    val dir = File(context.cacheDir, "wear-incoming").apply { mkdirs() }
                    val file = File.createTempFile("wear-", ".bin", dir)
                    try {
                        file.outputStream().use { dst -> src.copyTo(dst) }
                        file
                    } catch (e: Exception) {
                        file.delete()
                        throw e
                    }
                }
            } finally {
                response.release()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Unable to read Wear asset", e)
            null
        }
    }
}
