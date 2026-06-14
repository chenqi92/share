package com.welape.meshdrop.wear.bridge

import android.content.Context
import android.net.Uri
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import java.util.UUID

/**
 * Wear 端模拟 Android `ShareEngine` 的对外接口。
 *
 * 所有方法都把请求转给 [WearSessionClient]，经 WearableDataLayer 转发给配对的 phone。
 * Composable 不可直接调 Wearable API —— 必须经此入口。
 */
class WearEngineProxy private constructor(context: Context) {

    private val appContext = context.applicationContext
    private val session = WearSessionClient(appContext)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val _devices = MutableStateFlow<List<Device>>(emptyList())
    val devices: StateFlow<List<Device>> = _devices.asStateFlow()

    private val _history = MutableStateFlow<List<HistoryItem>>(emptyList())
    val history: StateFlow<List<HistoryItem>> = _history.asStateFlow()

    private val _pendingOffers = MutableStateFlow<List<Offer>>(emptyList())
    val pendingOffers: StateFlow<List<Offer>> = _pendingOffers.asStateFlow()

    private val _pendingPairings = MutableStateFlow<List<Pairing>>(emptyList())
    val pendingPairings: StateFlow<List<Pairing>> = _pendingPairings.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    val isOnline: StateFlow<Boolean> = session.isOnline

    fun start() {
        session.start()
        scope.launch {
            session.events.collectLatest { handleEvent(it) }
        }
        scope.launch { refreshState() }
        session.isOnline
            .onEach { online ->
                if (online) refreshState() else clearState()
            }
            .launchIn(scope)
    }

    fun stop() {
        session.stop()
        clearState()
    }

    suspend fun sendText(peerId: String, text: String): Result<Unit> {
        if (!session.isOnline.value) return failOffline()
        val payload = bridgeJson.encodeToJsonElement(SendTextPayload(peerId, text))
        val resp = session.send(CmdType.SEND_TEXT, payload)
        return resp.toResult()
    }

    suspend fun sendFileRef(peerId: String, fileUri: Uri, name: String, sizeBytes: Long, mime: String = "application/octet-stream"): Result<Unit> {
        if (!session.isOnline.value) return failOffline()
        // 与 README/能力声明一致：wear 不发大文件，>10 MiB 由本端直接拒绝
        if (sizeBytes > MAX_FILE_BYTES) {
            _lastError.value = "file_too_large"
            return Result.failure(IllegalArgumentException("file_too_large"))
        }
        val transferId = "wear-${UUID.randomUUID()}"
        return runCatching { session.putFileAsset(fileUri, transferId) }
            .fold(
                onSuccess = {
                    // fileRef 必须是完整 DataItem path（/meshdrop/files/<id>），
                    // phone 端按 path 解析 DataItem；传裸 id 会 100% asset_fetch_failed
                    val fileRef = BridgePaths.FILES_PREFIX + transferId
                    val payload = bridgeJson.encodeToJsonElement(
                        SendFileRefPayload(peerId, fileRef, name, sizeBytes, mime),
                    )
                    session.send(CmdType.SEND_FILE_REF, payload).toResult()
                },
                onFailure = { Result.failure(it) },
            )
    }

    suspend fun acceptOffer(offerId: String): Result<Unit> =
        sendOfferDecision(CmdType.ACCEPT_OFFER, offerId)

    suspend fun rejectOffer(offerId: String): Result<Unit> =
        sendOfferDecision(CmdType.REJECT_OFFER, offerId)

    private suspend fun sendOfferDecision(type: String, offerId: String): Result<Unit> {
        if (!session.isOnline.value) return failOffline()
        val payload = bridgeJson.encodeToJsonElement(OfferIdPayload(offerId))
        val resp = session.send(type, payload)
        if (resp.ok) {
            // 立即从待审列表里摘掉，避免 UI 残留
            _pendingOffers.value = _pendingOffers.value.filterNot { it.id == offerId }
        }
        return resp.toResult()
    }

    suspend fun acceptPairing(pairingId: String, trust: Boolean = true): Result<Unit> =
        sendPairingDecision(CmdType.ACCEPT_PAIRING, pairingId, trust)

    suspend fun rejectPairing(pairingId: String): Result<Unit> =
        sendPairingDecision(CmdType.REJECT_PAIRING, pairingId, trust = false)

    private suspend fun sendPairingDecision(type: String, pairingId: String, trust: Boolean): Result<Unit> {
        if (!session.isOnline.value) return failOffline()
        val payload = bridgeJson.encodeToJsonElement(PairingDecisionPayload(pairingId, trust))
        val resp = session.send(type, payload)
        if (resp.ok) {
            _pendingPairings.value = _pendingPairings.value.filterNot { it.id == pairingId }
        }
        return resp.toResult()
    }

    private fun handleEvent(evt: Evt) {
        runCatching {
            when (evt.type) {
                EvtType.DEVICE_ADDED -> {
                    val dev = decode<Device>(evt.payload)
                    _devices.value = _devices.value.upsert(dev) { it.id }
                }
                EvtType.DEVICE_REMOVED -> {
                    val payload = decode<DeviceRemoved>(evt.payload)
                    _devices.value = _devices.value.filterNot { it.id == payload.id }
                }
                EvtType.DEVICE_UPDATED -> {
                    val dev = decode<Device>(evt.payload)
                    _devices.value = _devices.value.upsert(dev) { it.id }
                }
                EvtType.OFFER_PENDING -> {
                    val offer = decode<Offer>(evt.payload)
                    _pendingOffers.value = _pendingOffers.value.upsert(offer) { it.id }
                }
                EvtType.PAIRING_PENDING -> {
                    val pairing = decode<Pairing>(evt.payload)
                    _pendingPairings.value = _pendingPairings.value.upsert(pairing) { it.id }
                }
                EvtType.TRANSFER_DONE -> {
                    val done = decode<TransferDone>(evt.payload)
                    if (!done.ok) _lastError.value = done.error ?: "transfer_failed"
                }
                EvtType.HISTORY_ADDED -> {
                    val item = decode<HistoryItem>(evt.payload)
                    _history.value = (listOf(item) + _history.value).distinctBy { it.id }
                }
                else -> Unit
            }
        }.onFailure { Log.w(TAG, "event handle error", it) }
    }

    private suspend fun refreshState() {
        val resp = session.send(CmdType.GET_STATE)
        if (!resp.ok) {
            _lastError.value = resp.error
            return
        }
        runCatching {
            val result = resp.result ?: return@runCatching
            // 直接对 JsonElement 解码，免去 encodeToString → decodeFromString 的二次往返
            val snap = bridgeJson.decodeFromJsonElement<StateSnapshot>(result)
            _devices.value = snap.devices
            _history.value = snap.history
            _pendingOffers.value = snap.pendingOffers
            _pendingPairings.value = snap.pendingPairings
        }.onFailure { Log.w(TAG, "state decode error", it) }
    }

    private fun clearState() {
        _devices.value = emptyList()
        _history.value = emptyList()
        _pendingOffers.value = emptyList()
        _pendingPairings.value = emptyList()
    }

    private fun failOffline(): Result<Unit> {
        _lastError.value = "offline"
        return Result.failure(IllegalStateException("offline"))
    }

    private inline fun <reified T> decode(payload: kotlinx.serialization.json.JsonElement?): T {
        requireNotNull(payload) { "payload missing" }
        return bridgeJson.decodeFromJsonElement(payload)
    }

    private fun <T> List<T>.upsert(item: T, key: (T) -> String): List<T> {
        val k = key(item)
        val replaced = map { if (key(it) == k) item else it }
        return if (replaced.any { key(it) == k }) replaced else replaced + item
    }

    private fun CmdResp.toResult(): Result<Unit> =
        if (ok) Result.success(Unit) else {
            _lastError.value = error
            Result.failure(IllegalStateException(error ?: "unknown"))
        }

    /** 给 WearableListenerService 注入消息用 —— 不暴露给 UI。 */
    internal fun injectMessage(path: String, data: ByteArray) {
        scope.launch {
            when (path) {
                BridgePaths.EVT -> runCatching {
                    val evt = bridgeJson.decodeFromString<Evt>(data.toString(Charsets.UTF_8))
                    handleEvent(evt)
                }
                // 回执经 Service 这路到达时，交回同一个 pending map 才能 complete 等待者，
                // 否则命令一律走到 10s 超时
                BridgePaths.CMD_RESP -> session.injectResp(data)
            }
        }
    }

    companion object {
        private const val TAG = "WearEngineProxy"

        /** wear 端文件发送上限：10 MiB，超过由本端直接拒绝并提示用 phone（与 README 声明一致）。 */
        const val MAX_FILE_BYTES = 10L * 1024 * 1024

        @Volatile
        private var INSTANCE: WearEngineProxy? = null

        fun init(context: Context): WearEngineProxy {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: WearEngineProxy(context).also { INSTANCE = it }
            }
        }

        /** Composable 使用入口；要求 App.onCreate 已调过 [init]。 */
        val instance: WearEngineProxy
            get() = INSTANCE ?: error("WearEngineProxy not initialized; call init() in Application.onCreate")

        internal fun peekInstance(): WearEngineProxy? = INSTANCE
    }
}
