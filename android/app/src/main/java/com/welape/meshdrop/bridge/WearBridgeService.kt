package com.welape.meshdrop.bridge

import android.net.Uri
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import com.welape.meshdrop.ShareApplication
import com.welape.meshdrop.data.PairingDecision
import com.welape.meshdrop.transport.ShareEngine
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

private const val TAG = "WearBridge"

/**
 * Wear Companion Bridge — phone 端 service：
 * - 监听 `/meshdrop/cmd`：解析 [WearCmdEnvelope] → 调 [ShareEngine] 对应方法
 * - 通过 `MessageClient.sendMessage(nodeId, "/meshdrop/cmdresp", ...)` 回执
 * - [WearEventPusher] 订阅 engine 状态变化 → push `/meshdrop/evt`
 *
 * companion-bridges.md §4.2 规定 nodeId 由 [com.google.android.gms.wearable.NodeClient]
 * 动态查 connected nodes，禁止 hardcode（PROMPT 也明确）。
 */
class WearBridgeService : WearableListenerService() {

    private val messageClient: MessageClient by lazy { Wearable.getMessageClient(this) }
    private val assetTransfer: WearAssetTransfer by lazy { WearAssetTransfer(this) }

    private fun engine(): ShareEngine? =
        (applicationContext as? ShareApplication)?.engine

    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != WearBridgePaths.CMD) return
        val payload = event.data
        val raw = runCatching { String(payload, Charsets.UTF_8) }.getOrNull()
        if (raw.isNullOrBlank()) {
            Log.w(TAG, "empty cmd payload from ${event.sourceNodeId}")
            return
        }
        val envelope = runCatching {
            wearBridgeJson.decodeFromString(WearCmdEnvelope.serializer(), raw)
        }.onFailure { Log.e(TAG, "bad cmd json", it) }.getOrNull() ?: return

        handleCommand(event.sourceNodeId, envelope)
    }

    private fun handleCommand(sourceNodeId: String, env: WearCmdEnvelope) {
        val engine = engine()
        if (engine == null) {
            replyError(sourceNodeId, env.id, "engine_unavailable")
            return
        }
        try {
            when (env.type) {
                WearCmdType.LIST_DEVICES -> {
                    val devices = engine.devices.value.map { it.toBridgeJson() }
                    reply(sourceNodeId, env.id, ok = true, result = JsonArray(devices))
                }
                WearCmdType.GET_STATE -> {
                    val state = buildJsonObject {
                        put("devices", JsonArray(engine.devices.value.map { it.toBridgeJson() }))
                        put("history", JsonArray(engine.history.value.map { it.toBridgeJson() }))
                        put("pendingPairings", JsonArray(engine.pendingPairings.value.map { it.toBridgeJson() }))
                        put("pendingOffers", JsonArray(engine.pendingFileOffers.value.map { it.toBridgeJson() }))
                    }
                    reply(sourceNodeId, env.id, ok = true, result = state)
                }
                WearCmdType.SEND_TEXT -> {
                    val payload = env.payload ?: return replyError(sourceNodeId, env.id, "missing_payload")
                    val peerId = payload.stringField("peerId")
                        ?: return replyError(sourceNodeId, env.id, "missing_peerId")
                    val text = payload.stringField("text")
                        ?: return replyError(sourceNodeId, env.id, "missing_text")
                    val device = engine.devices.value.firstOrNull { it.id == peerId }
                        ?: return replyError(sourceNodeId, env.id, "peer_not_found")
                    engine.sendText(device, text)
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                WearCmdType.SEND_FILE_REF -> {
                    val payload = env.payload ?: return replyError(sourceNodeId, env.id, "missing_payload")
                    val peerId = payload.stringField("peerId")
                        ?: return replyError(sourceNodeId, env.id, "missing_peerId")
                    val fileRef = payload.stringField("fileRef")
                        ?: return replyError(sourceNodeId, env.id, "missing_fileRef")
                    val name = payload.stringField("name") ?: "wear-file.bin"
                    val sizeBytes = payload.longField("sizeBytes") ?: 0L
                    val device = engine.devices.value.firstOrNull { it.id == peerId }
                        ?: return replyError(sourceNodeId, env.id, "peer_not_found")
                    val uri: Uri? = assetTransfer.fetchAssetToLocal(fileRef, name)
                    if (uri == null) return replyError(sourceNodeId, env.id, "asset_fetch_failed")
                    engine.sendFile(device, uri, name, sizeBytes)
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                WearCmdType.ACCEPT_OFFER -> {
                    val offerId = env.payload?.stringField("offerId")?.let { runCatching { UUID.fromString(it) }.getOrNull() }
                        ?: return replyError(sourceNodeId, env.id, "missing_offerId")
                    engine.respondToFileOffer(offerId, accept = true)
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                WearCmdType.REJECT_OFFER -> {
                    val offerId = env.payload?.stringField("offerId")?.let { runCatching { UUID.fromString(it) }.getOrNull() }
                        ?: return replyError(sourceNodeId, env.id, "missing_offerId")
                    engine.respondToFileOffer(offerId, accept = false)
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                WearCmdType.ACCEPT_PAIRING -> {
                    val payload = env.payload ?: return replyError(sourceNodeId, env.id, "missing_payload")
                    val pairingId = payload.stringField("pairingId")?.let { runCatching { UUID.fromString(it) }.getOrNull() }
                        ?: return replyError(sourceNodeId, env.id, "missing_pairingId")
                    val trust = payload.boolField("trust") ?: false
                    val decision = if (trust) PairingDecision.TRUST else PairingDecision.ALLOW_ONCE
                    engine.respondToPairing(pairingId, decision)
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                WearCmdType.REJECT_PAIRING -> {
                    val pairingId = env.payload?.stringField("pairingId")?.let { runCatching { UUID.fromString(it) }.getOrNull() }
                        ?: return replyError(sourceNodeId, env.id, "missing_pairingId")
                    engine.respondToPairing(pairingId, PairingDecision.REJECT)
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                WearCmdType.CLEAR_HISTORY -> {
                    engine.clearHistory()
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                WearCmdType.DELETE_HISTORY_ITEM -> {
                    val itemId = env.payload?.stringField("itemId")?.let { runCatching { UUID.fromString(it) }.getOrNull() }
                        ?: return replyError(sourceNodeId, env.id, "missing_itemId")
                    engine.removeHistoryItem(itemId)
                    reply(sourceNodeId, env.id, ok = true, result = JsonNull)
                }
                else -> replyError(sourceNodeId, env.id, "unknown_type:${env.type}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "handleCommand ${env.type} failed", e)
            replyError(sourceNodeId, env.id, e.message ?: "exception")
        }
    }

    private fun reply(
        sourceNodeId: String,
        cmdId: String,
        ok: Boolean,
        result: kotlinx.serialization.json.JsonElement,
    ) {
        val resp = WearCmdResponse(id = cmdId, ok = ok, error = null, result = result)
        sendResponse(sourceNodeId, resp)
    }

    private fun replyError(sourceNodeId: String, cmdId: String, message: String) {
        Log.w(TAG, "cmd $cmdId failed: $message")
        sendResponse(sourceNodeId, WearCmdResponse(id = cmdId, ok = false, error = message))
    }

    private fun sendResponse(sourceNodeId: String, resp: WearCmdResponse) {
        try {
            val bytes = wearBridgeJson.encodeToString(WearCmdResponse.serializer(), resp)
                .toByteArray(Charsets.UTF_8)
            Tasks.await(
                messageClient.sendMessage(sourceNodeId, WearBridgePaths.CMD_RESP, bytes),
                10, TimeUnit.SECONDS,
            )
        } catch (e: Exception) {
            Log.e(TAG, "send response failed", e)
        }
    }

    /** 工具：JSON field 取值。 */
    private fun JsonObject.stringField(name: String): String? =
        get(name)?.jsonPrimitive?.contentOrNull

    private fun JsonObject.longField(name: String): Long? =
        get(name)?.jsonPrimitive?.contentOrNull?.toLongOrNull()

    private fun JsonObject.boolField(name: String): Boolean? =
        get(name)?.jsonPrimitive?.contentOrNull?.toBooleanStrictOrNull()
}
