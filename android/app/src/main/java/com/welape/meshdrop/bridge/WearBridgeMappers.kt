package com.welape.meshdrop.bridge

import com.welape.meshdrop.data.Device
import com.welape.meshdrop.data.HistoryItem
import com.welape.meshdrop.data.HistoryKind
import com.welape.meshdrop.data.PendingFileOffer
import com.welape.meshdrop.data.PendingPairing
import com.welape.meshdrop.data.TransferDirection
import com.welape.meshdrop.data.TransferStatus
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.add
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * companion-bridges.md §3 共享状态 schema：把 ShareEngine 的 model 序列化成 wear 端能直接渲染的 JSON。
 */

fun Device.toBridgeJson(): JsonObject = buildJsonObject {
    put("id", id)
    put("displayName", name)
    put("kind", kindLabel())
    put("model", model ?: "")
    put("ip", host ?: "")
    put("rttMs", 0)
    put("online", true)
    put("trusted", false)
    put("busy", false)
}

private fun Device.kindLabel(): String = when (os) {
    com.welape.meshdrop.data.DeviceOS.MACOS -> "mac"
    com.welape.meshdrop.data.DeviceOS.IOS -> "ios"
    com.welape.meshdrop.data.DeviceOS.ANDROID -> "android"
    com.welape.meshdrop.data.DeviceOS.WINDOWS -> "win"
    com.welape.meshdrop.data.DeviceOS.LINUX -> "linux"
}

fun PendingPairing.toBridgeJson(): JsonObject = buildJsonObject {
    put("id", id.toString())
    put("peerName", peer.name)
    put("code", "")
    put("fingerprint", peer.fingerprint)
    put("createdAt", System.currentTimeMillis() / 1000)
}

fun PendingFileOffer.toBridgeJson(): JsonObject = buildJsonObject {
    put("id", id.toString())
    put("peerId", peer.id)
    put("peerName", peer.name)
    put("kind", "file")
    put("files", buildJsonArray {
        add(buildJsonObject {
            put("name", fileName)
            put("sizeBytes", fileSize)
            put("mime", "application/octet-stream")
        })
    })
    put("noteText", "")
    put("createdAt", System.currentTimeMillis() / 1000)
}

fun HistoryItem.toBridgeJson(): JsonObject = buildJsonObject {
    put("id", id.toString())
    put("direction", when (direction) {
        TransferDirection.OUTGOING -> "sent"
        TransferDirection.INCOMING -> "received"
    })
    put("peerName", peer.name)
    when (val k = kind) {
        is HistoryKind.Text -> {
            put("kind", "text")
            put("text", k.content)
            put("files", JsonArray(emptyList()))
        }
        is HistoryKind.File -> {
            put("kind", "file")
            put("files", buildJsonArray {
                add(buildJsonObject {
                    put("name", k.name)
                    put("sizeBytes", k.size)
                    put("mime", "application/octet-stream")
                })
            })
        }
    }
    val bytesTransferred = when (val s = status) {
        is TransferStatus.Transferring -> s.bytesDone
        TransferStatus.Completed -> when (val k = kind) {
            is HistoryKind.File -> k.size
            else -> 0L
        }
        else -> 0L
    }
    put("bytesTransferred", bytesTransferred)
    put("ok", status is TransferStatus.Completed)
    put("completedAt", createdAt / 1000)
}
