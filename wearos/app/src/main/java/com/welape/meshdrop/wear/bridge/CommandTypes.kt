package com.welape.meshdrop.wear.bridge

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * Companion 桥接协议（v=1）的 wear 侧 DTO。
 * 严格按 protocol/companion-bridges.md 实现：
 *   - 命令路径 /meshdrop/cmd
 *   - 回执路径 /meshdrop/cmdresp
 *   - 事件路径 /meshdrop/evt
 *   - 文件路径前缀 /meshdrop/files/<id>
 */
internal object BridgePaths {
    const val CMD = "/meshdrop/cmd"
    const val CMD_RESP = "/meshdrop/cmdresp"
    const val EVT = "/meshdrop/evt"
    const val FILES_PREFIX = "/meshdrop/files/"
}

internal object BridgeProtocol {
    const val VERSION = 1
    const val CMD_TIMEOUT_MS = 10_000L
}

internal val bridgeJson: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
    explicitNulls = false
}

@Serializable
internal data class Cmd(
    val v: Int = BridgeProtocol.VERSION,
    val id: String,
    val type: String,
    val ts: Long,
    val payload: JsonElement? = null,
)

@Serializable
internal data class CmdResp(
    val v: Int = BridgeProtocol.VERSION,
    val id: String,
    val ok: Boolean,
    val error: String? = null,
    val result: JsonElement? = null,
)

@Serializable
internal data class Evt(
    val v: Int = BridgeProtocol.VERSION,
    val id: String,
    val type: String,
    val ts: Long,
    val payload: JsonElement? = null,
)

@Serializable
data class Device(
    val id: String,
    val displayName: String,
    val kind: String,
    val model: String = "",
    val ip: String = "",
    val rttMs: Int = 0,
    val online: Boolean = true,
    val trusted: Boolean = false,
    val busy: Boolean = false,
)

@Serializable
data class FileMeta(
    val name: String,
    val sizeBytes: Long,
    val mime: String = "application/octet-stream",
)

@Serializable
data class Offer(
    val id: String,
    val peerId: String,
    val peerName: String,
    val kind: String,
    val files: List<FileMeta> = emptyList(),
    val noteText: String? = null,
    val createdAt: Long = 0,
)

@Serializable
data class HistoryItem(
    val id: String,
    val direction: String,
    val peerName: String,
    val kind: String,
    val text: String? = null,
    val files: List<FileMeta> = emptyList(),
    val bytesTransferred: Long = 0,
    val ok: Boolean = true,
    val completedAt: Long = 0,
)

@Serializable
internal data class StateSnapshot(
    val devices: List<Device> = emptyList(),
    val history: List<HistoryItem> = emptyList(),
    val pendingOffers: List<Offer> = emptyList(),
)

@Serializable
internal data class TransferProgress(
    val id: String,
    val bytesSent: Long,
    val totalBytes: Long,
    val speedBps: Long = 0,
)

@Serializable
internal data class TransferDone(
    val id: String,
    val ok: Boolean,
    val error: String? = null,
)

@Serializable
internal data class DeviceRemoved(val id: String)

@Serializable
internal data class Pairing(
    val id: String,
    val peerName: String,
    val code: String,
    val fingerprint: String,
    val createdAt: Long = 0,
)

internal object CmdType {
    const val LIST_DEVICES = "list_devices"
    const val GET_STATE = "get_state"
    const val SEND_TEXT = "send_text"
    const val SEND_FILE_REF = "send_file_ref"
    const val ACCEPT_OFFER = "accept_offer"
    const val REJECT_OFFER = "reject_offer"
    const val ACCEPT_PAIRING = "accept_pairing"
    const val REJECT_PAIRING = "reject_pairing"
    const val CLEAR_HISTORY = "clear_history"
    const val DELETE_HISTORY_ITEM = "delete_history_item"
}

internal object EvtType {
    const val DEVICE_ADDED = "device_added"
    const val DEVICE_REMOVED = "device_removed"
    const val DEVICE_UPDATED = "device_updated"
    const val PAIRING_PENDING = "pairing_pending"
    const val OFFER_PENDING = "offer_pending"
    const val TRANSFER_PROGRESS = "transfer_progress"
    const val TRANSFER_DONE = "transfer_done"
    const val HISTORY_ADDED = "history_added"
}

@Serializable
internal data class SendTextPayload(
    val peerId: String,
    val text: String,
)

@Serializable
internal data class SendFileRefPayload(
    val peerId: String,
    val fileRef: String,
    val name: String,
    val sizeBytes: Long,
    val mime: String,
)

@Serializable
internal data class OfferIdPayload(val offerId: String)

@Serializable
internal data class PairingDecisionPayload(val pairingId: String, val trust: Boolean = false)

internal fun emptyJsonObject(): JsonElement = JsonObject(emptyMap())
