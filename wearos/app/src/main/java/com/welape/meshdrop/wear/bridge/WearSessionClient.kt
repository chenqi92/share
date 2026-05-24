package com.welape.meshdrop.wear.bridge

import android.content.Context
import android.net.Uri
import android.util.Log
import com.google.android.gms.tasks.Task
import com.google.android.gms.wearable.Asset
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Node
import com.google.android.gms.wearable.NodeClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.JsonElement
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

/**
 * 负责与配对 phone 的 WearableDataLayer 通讯：
 *   - 节点发现（只选 nearby companion 节点）
 *   - 命令发送 + 回执等待
 *   - 接收 phone 推过来的事件，转成 SharedFlow
 *   - 文件 send 用 DataClient.putDataItem
 */
internal class WearSessionClient(private val context: Context) {

    private val nodeClient: NodeClient by lazy { Wearable.getNodeClient(context) }
    private val messageClient: MessageClient by lazy { Wearable.getMessageClient(context) }
    private val dataClient: DataClient by lazy { Wearable.getDataClient(context) }
    private val capabilityClient: CapabilityClient by lazy { Wearable.getCapabilityClient(context) }

    private val pending = ConcurrentHashMap<String, CompletableDeferred<CmdResp>>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _isOnline = MutableStateFlow(false)
    val isOnline: StateFlow<Boolean> = _isOnline.asStateFlow()

    private val _events = MutableSharedFlow<Evt>(extraBufferCapacity = 32)
    val events: SharedFlow<Evt> = _events.asSharedFlow()

    @Volatile
    private var companionNodeId: String? = null

    private val messageListener = MessageClient.OnMessageReceivedListener { msg ->
        when (msg.path) {
            BridgePaths.CMD_RESP -> handleResp(msg.data)
            BridgePaths.EVT -> handleEvt(msg.data)
        }
    }

    fun start() {
        messageClient.addListener(messageListener)
        scope.launch { refreshCompanionNode() }
    }

    fun stop() {
        runCatching { messageClient.removeListener(messageListener) }
        pending.values.forEach { it.cancel() }
        pending.clear()
        _isOnline.value = false
    }

    suspend fun refreshCompanionNode(): String? {
        return runCatching {
            val nodes: List<Node> = nodeClient.connectedNodes.await()
            val pick = nodes.firstOrNull { it.isNearby } ?: nodes.firstOrNull()
            companionNodeId = pick?.id
            _isOnline.value = pick != null
            pick?.id
        }.getOrElse {
            Log.w(TAG, "node discovery failed", it)
            companionNodeId = null
            _isOnline.value = false
            null
        }
    }

    /** 发送命令并等待回执。10s 超时返回 ok=false。 */
    suspend fun send(type: String, payload: JsonElement? = null): CmdResp {
        val nodeId = companionNodeId ?: refreshCompanionNode()
        if (nodeId == null) {
            return CmdResp(id = "", ok = false, error = "no_companion")
        }
        val cmd = Cmd(
            id = "cmd-${UUID.randomUUID()}",
            type = type,
            ts = System.currentTimeMillis() / 1000,
            payload = payload,
        )
        val bytes = bridgeJson.encodeToString(cmd).toByteArray(Charsets.UTF_8)
        val waiter = CompletableDeferred<CmdResp>()
        pending[cmd.id] = waiter
        try {
            runCatching { messageClient.sendMessage(nodeId, BridgePaths.CMD, bytes).await() }
                .onFailure {
                    pending.remove(cmd.id)
                    Log.w(TAG, "sendMessage failed", it)
                    return CmdResp(id = cmd.id, ok = false, error = "send_failed: ${it.message}")
                }
            return withTimeoutOrNull(BridgeProtocol.CMD_TIMEOUT_MS) { waiter.await() }
                ?: CmdResp(id = cmd.id, ok = false, error = "timeout")
        } finally {
            pending.remove(cmd.id)
        }
    }

    /** 把本地 Uri 转 Asset，写到 path /meshdrop/files/<id> 让 phone 端的 DataListener 拉取。 */
    suspend fun putFileAsset(fileUri: Uri, transferId: String) {
        val nodeId = companionNodeId ?: refreshCompanionNode() ?: error("no_companion")
        val asset = uriToAsset(fileUri) ?: error("asset_open_failed")
        val request = PutDataMapRequest.create(BridgePaths.FILES_PREFIX + transferId).apply {
            dataMap.putAsset("file", asset)
            dataMap.putLong("ts", System.currentTimeMillis())
            dataMap.putString("nodeId", nodeId)
        }.asPutDataRequest().setUrgent()
        dataClient.putDataItem(request).await()
    }

    private fun uriToAsset(uri: Uri): Asset? {
        return runCatching {
            context.contentResolver.openInputStream(uri)?.use { ins ->
                Asset.createFromBytes(ins.readBytes())
            }
        }.getOrNull()
    }

    private fun handleResp(data: ByteArray) {
        val resp = runCatching {
            bridgeJson.decodeFromString<CmdResp>(data.toString(Charsets.UTF_8))
        }.getOrNull() ?: return
        pending.remove(resp.id)?.complete(resp)
    }

    private fun handleEvt(data: ByteArray) {
        val evt = runCatching {
            bridgeJson.decodeFromString<Evt>(data.toString(Charsets.UTF_8))
        }.getOrNull() ?: return
        scope.launch { _events.emit(evt) }
    }

    companion object {
        private const val TAG = "WearSession"
    }
}
