package com.welape.meshdrop.bridge

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject

/**
 * Wear Companion Bridge：phone ↔ wear 之间的命令 / 事件 JSON。
 * 与 [protocol/companion-bridges.md §1+§2+§3] 保持一致（v=1）。
 *
 * 传输路径：
 *   /meshdrop/cmd      wear → phone 命令
 *   /meshdrop/cmdresp  phone → wear 命令回执
 *   /meshdrop/evt      phone → wear 事件
 *   /meshdrop/files/<id>  wear 端 DataClient asset，phone 读出后入 ShareEngine
 */
object WearBridgePaths {
    const val CMD = "/meshdrop/cmd"
    const val CMD_RESP = "/meshdrop/cmdresp"
    const val EVT = "/meshdrop/evt"
    const val FILES_PREFIX = "/meshdrop/files/"
}

/** v=1 协议版本号。 */
const val WEAR_BRIDGE_VERSION = 1

@Serializable
data class WearCmdEnvelope(
    val v: Int = WEAR_BRIDGE_VERSION,
    val id: String,
    val type: String,
    val ts: Long,
    val payload: JsonObject? = null,
)

@Serializable
data class WearCmdResponse(
    val v: Int = WEAR_BRIDGE_VERSION,
    val id: String,
    val ok: Boolean,
    val error: String? = null,
    val result: JsonElement? = null,
)

@Serializable
data class WearEventEnvelope(
    val v: Int = WEAR_BRIDGE_VERSION,
    val id: String,
    val type: String,
    val ts: Long,
    val payload: JsonElement,
)

/** §1.1 命令类型。 */
object WearCmdType {
    const val LIST_DEVICES = "list_devices"
    const val SEND_TEXT = "send_text"
    const val SEND_FILE_REF = "send_file_ref"
    const val ACCEPT_OFFER = "accept_offer"
    const val REJECT_OFFER = "reject_offer"
    const val ACCEPT_PAIRING = "accept_pairing"
    const val REJECT_PAIRING = "reject_pairing"
    const val CLEAR_HISTORY = "clear_history"
    const val DELETE_HISTORY_ITEM = "delete_history_item"
    const val GET_STATE = "get_state"
}

/** §2 事件类型。 */
object WearEventType {
    const val DEVICE_ADDED = "device_added"
    const val DEVICE_REMOVED = "device_removed"
    const val DEVICE_UPDATED = "device_updated"
    const val PAIRING_PENDING = "pairing_pending"
    const val OFFER_PENDING = "offer_pending"
    const val TRANSFER_PROGRESS = "transfer_progress"
    const val TRANSFER_DONE = "transfer_done"
    const val HISTORY_ADDED = "history_added"
}

/** 共享 JSON 解析器：缺字段忽略，松松散散即可。 */
val wearBridgeJson: Json = Json {
    ignoreUnknownKeys = true
    encodeDefaults = true
}
