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
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
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
        val transferId = "wear-${UUID.randomUUID()}"
        return runCatching { session.putFileAsset(fileUri, transferId) }
            .fold(
                onSuccess = {
                    val payload = bridgeJson.encodeToJsonElement(
                        SendFileRefPayload(peerId, transferId, name, sizeBytes, mime),
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
            val snap = bridgeJson.decodeFromString<StateSnapshot>(
                Json.Default.encodeToString(resp.result ?: return@runCatching),
            )
            _devices.value = snap.devices
            _history.value = snap.history
            _pendingOffers.value = snap.pendingOffers
        }.onFailure { Log.w(TAG, "state decode error", it) }
    }

    private fun clearState() {
        _devices.value = emptyList()
        _history.value = emptyList()
        _pendingOffers.value = emptyList()
    }

    private fun failOffline(): Result<Unit> {
        _lastError.value = "offline"
        return Result.failure(IllegalStateException("offline"))
    }

    private inline fun <reified T> decode(payload: kotlinx.serialization.json.JsonElement?): T {
        requireNotNull(payload) { "payload missing" }
        return bridgeJson.decodeFromString(Json.Default.encodeToString(payload))
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
            }
        }
    }

    companion object {
        private const val TAG = "WearEngineProxy"

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
