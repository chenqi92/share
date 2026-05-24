package com.welape.meshdrop.bridge

import android.content.Context
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.NodeClient
import com.google.android.gms.wearable.Wearable
import com.welape.meshdrop.data.HistoryItem
import com.welape.meshdrop.data.PendingFileOffer
import com.welape.meshdrop.data.PendingPairing
import com.welape.meshdrop.data.TransferStatus
import com.welape.meshdrop.transport.ShareEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID
import java.util.concurrent.TimeUnit

private const val TAG = "WearEventPusher"

/**
 * 订阅 [ShareEngine] 状态变化 → push `/meshdrop/evt` 给所有 connected wear nodes
 * （companion-bridges.md §2 / §4.2）。
 *
 * 启动方式：在 [com.welape.meshdrop.ShareApplication] 里随 engine.start() 一起拉起。
 */
class WearEventPusher(
    private val context: Context,
    private val engine: ShareEngine,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val nodeClient: NodeClient by lazy { Wearable.getNodeClient(context) }
    private val messageClient by lazy { Wearable.getMessageClient(context) }

    private var jobs: MutableList<Job> = mutableListOf()

    fun start() {
        if (jobs.isNotEmpty()) return

        // 设备增量 — 比较快照差，分别发 device_added / device_removed
        jobs += scope.launch {
            var prev = engine.devices.value.map { it.id }.toSet()
            engine.devices.drop(1).collect { snap ->
                val now = snap.map { it.id }.toSet()
                val added = snap.filter { it.id !in prev }
                val removed = prev - now
                added.forEach { push(WearEventType.DEVICE_ADDED, it.toBridgeJson()) }
                removed.forEach { id ->
                    push(WearEventType.DEVICE_REMOVED, buildJsonObject { put("id", id) })
                }
                prev = now
            }
        }

        // 配对待审
        jobs += scope.launch {
            var prev = engine.pendingPairings.value.map { it.id }.toSet()
            engine.pendingPairings.drop(1).collect { snap ->
                val now = snap.map { it.id }.toSet()
                val added: List<PendingPairing> = snap.filter { it.id !in prev }
                added.forEach { push(WearEventType.PAIRING_PENDING, it.toBridgeJson()) }
                prev = now
            }
        }

        // 文件待审
        jobs += scope.launch {
            var prev = engine.pendingFileOffers.value.map { it.id }.toSet()
            engine.pendingFileOffers.drop(1).collect { snap ->
                val now = snap.map { it.id }.toSet()
                val added: List<PendingFileOffer> = snap.filter { it.id !in prev }
                added.forEach { push(WearEventType.OFFER_PENDING, it.toBridgeJson()) }
                prev = now
            }
        }

        // 历史 / 进度
        jobs += scope.launch {
            var prevIds = engine.history.value.map { it.id }.toSet()
            engine.history.collect { snap ->
                val nowIds = snap.map { it.id }.toSet()
                val addedItems: List<HistoryItem> = snap.filter { it.id !in prevIds }
                addedItems.forEach { push(WearEventType.HISTORY_ADDED, it.toBridgeJson()) }

                // 进度 / 完成
                snap.forEach { item ->
                    when (val s = item.status) {
                        is TransferStatus.Transferring -> push(
                            WearEventType.TRANSFER_PROGRESS,
                            buildJsonObject {
                                put("id", item.id.toString())
                                put("bytesSent", s.bytesDone)
                                put("totalBytes", s.bytesTotal)
                                put("speedBps", 0)
                            },
                        )
                        TransferStatus.Completed -> if (item.id in addedItems.map { it.id } || item.id !in prevIds) {
                            push(
                                WearEventType.TRANSFER_DONE,
                                buildJsonObject {
                                    put("id", item.id.toString())
                                    put("ok", true)
                                    put("error", "")
                                },
                            )
                        }
                        is TransferStatus.Failed -> push(
                            WearEventType.TRANSFER_DONE,
                            buildJsonObject {
                                put("id", item.id.toString())
                                put("ok", false)
                                put("error", s.reason)
                            },
                        )
                        else -> Unit
                    }
                }
                prevIds = nowIds
            }
        }
    }

    fun stop() {
        jobs.forEach { it.cancel() }
        jobs.clear()
        scope.cancel()
    }

    private fun push(type: String, payload: JsonElement) {
        val nodes: List<Node> = try {
            Tasks.await(nodeClient.connectedNodes, 5, TimeUnit.SECONDS)
        } catch (e: Exception) {
            Log.w(TAG, "no connected nodes (${e.message})")
            return
        }
        if (nodes.isEmpty()) return

        val env = WearEventEnvelope(
            id = "evt-${UUID.randomUUID()}",
            type = type,
            ts = System.currentTimeMillis() / 1000,
            payload = payload,
        )
        val bytes = wearBridgeJson.encodeToString(WearEventEnvelope.serializer(), env)
            .toByteArray(Charsets.UTF_8)
        nodes.forEach { node ->
            try {
                Tasks.await(
                    messageClient.sendMessage(node.id, WearBridgePaths.EVT, bytes),
                    5, TimeUnit.SECONDS,
                )
            } catch (e: Exception) {
                Log.w(TAG, "push to ${node.id} failed: ${e.message}")
            }
        }
    }
}
