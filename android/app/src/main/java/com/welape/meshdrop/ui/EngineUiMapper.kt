package com.welape.meshdrop.ui

import com.welape.meshdrop.data.Device
import com.welape.meshdrop.data.DeviceOS
import com.welape.meshdrop.data.HistoryItem
import com.welape.meshdrop.data.HistoryKind
import com.welape.meshdrop.data.TransferDirection
import com.welape.meshdrop.data.TransferStatus
import com.welape.meshdrop.mock.DeviceKind
import com.welape.meshdrop.mock.HistoryDir
import com.welape.meshdrop.mock.HistoryKindMock
import com.welape.meshdrop.mock.HistoryStatus
import com.welape.meshdrop.mock.MockChatPreview
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.mock.MockHistoryItem
import com.welape.meshdrop.mock.MockMessage
import com.welape.meshdrop.mock.MsgKind
import com.welape.meshdrop.mock.MsgSide
import com.welape.meshdrop.mock.MsgState
import com.welape.meshdrop.ui.theme.AvatarLilac
import com.welape.meshdrop.ui.theme.AvatarMint
import com.welape.meshdrop.ui.theme.AvatarPeach
import com.welape.meshdrop.ui.theme.AvatarSky
import com.welape.meshdrop.ui.theme.AvatarSun
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs

/**
 * 把真实 ShareEngine 数据 → UI 层喜欢的 MockDevice / MockHistoryItem 形态。
 * MockDevice 留作 Preview 用，运行时由这里合成 UI 展示数据。
 */

private val avatarPalette = listOf(AvatarPeach, AvatarMint, AvatarLilac, AvatarSun, AvatarSky)

fun Device.toUiDevice(index: Int = 0): MockDevice {
    val totalCount = 5
    val angle = (index * (360 / totalCount.coerceAtLeast(1))) + 35
    val dist = 0.35f + ((index % 4) * 0.13f)
    val color = avatarPalette[abs(fingerprint.hashCode()) % avatarPalette.size]
    val initials = name.take(2).ifBlank { id.take(2) }.uppercase()
    return MockDevice(
        id = id,
        name = name.ifBlank { model ?: id.take(8) },
        who = name.ifBlank { "未命名" },
        kind = os.toKind(),
        dist = dist.coerceIn(0.2f, 0.95f),
        angleDeg = angle % 360,
        color = color,
        initials = initials,
        os = os.label(),
        rttMs = 0,
        online = true,
        ip = host ?: "—",
    )
}

private fun DeviceOS.toKind(): DeviceKind = when (this) {
    DeviceOS.MACOS -> DeviceKind.MAC
    DeviceOS.IOS -> DeviceKind.IPHONE
    DeviceOS.ANDROID -> DeviceKind.ANDROID
    DeviceOS.WINDOWS -> DeviceKind.WIN
    DeviceOS.LINUX -> DeviceKind.LINUX
}

private fun DeviceOS.label(): String = when (this) {
    DeviceOS.MACOS -> "macOS"
    DeviceOS.IOS -> "iOS"
    DeviceOS.ANDROID -> "Android"
    DeviceOS.WINDOWS -> "Windows"
    DeviceOS.LINUX -> "Linux"
}

private val timeFmt = SimpleDateFormat("HH:mm", Locale.getDefault())

fun HistoryItem.toUiHistoryItem(): MockHistoryItem {
    val dir = when (direction) {
        TransferDirection.OUTGOING -> HistoryDir.OUTGOING
        TransferDirection.INCOMING -> HistoryDir.INCOMING
    }
    val status = when (status) {
        is TransferStatus.Pending, TransferStatus.WaitingApproval -> HistoryStatus.QUEUED
        is TransferStatus.Transferring -> HistoryStatus.TRANSFERRING
        TransferStatus.Completed -> HistoryStatus.DONE
        is TransferStatus.Failed, TransferStatus.Canceled -> HistoryStatus.FAILED
    }
    val kind = when (val k = kind) {
        is HistoryKind.Text -> HistoryKindMock.Text(k.content)
        is HistoryKind.File -> {
            val ext = k.name.substringAfterLast('.', "bin").lowercase()
            val sizeLabel = humanSize(k.size)
            val progress = when (val s = this.status) {
                is TransferStatus.Transferring -> if (s.bytesTotal > 0) ((s.bytesDone * 100) / s.bytesTotal).toInt() else null
                else -> null
            }
            HistoryKindMock.File(k.name, sizeLabel, ext, progress)
        }
    }
    return MockHistoryItem(
        id = id.toString(),
        dir = dir,
        peer = peer.name.ifBlank { peer.model ?: peer.id.take(8) },
        time = timeFmt.format(Date(createdAt)),
        kind = kind,
        status = status,
    )
}

private fun humanSize(bytes: Long): String {
    if (bytes < 1024) return "$bytes B"
    val kb = bytes / 1024.0
    if (kb < 1024) return String.format(Locale.US, "%.1f KB", kb)
    val mb = kb / 1024.0
    if (mb < 1024) return String.format(Locale.US, "%.1f MB", mb)
    val gb = mb / 1024.0
    return String.format(Locale.US, "%.1f GB", gb)
}

/** 历史按 peerId 聚合，造出 chat list preview。 */
fun List<HistoryItem>.toChatPreviews(): List<MockChatPreview> {
    val byPeer = groupBy { it.peer.id }
    return byPeer.map { (_, items) ->
        val newest = items.maxByOrNull { it.createdAt }!!
        val snippet = when (val k = newest.kind) {
            is HistoryKind.Text -> k.content
            is HistoryKind.File -> k.name
        }
        val isFile = newest.kind is HistoryKind.File
        MockChatPreview(
            deviceId = newest.peer.id,
            lastSnippet = snippet,
            lastTime = timeFmt.format(Date(newest.createdAt)),
            unread = 0,
            isFile = isFile,
        )
    }.sortedByDescending { it.lastTime }
}

/** 历史按 peerId 投影成 ChatDetail 的消息流。 */
fun List<HistoryItem>.toChatMessages(peerId: String): List<MockMessage> =
    filter { it.peer.id == peerId }
        .sortedBy { it.createdAt }
        .map { item ->
            val side = when (item.direction) {
                TransferDirection.OUTGOING -> MsgSide.OUT
                TransferDirection.INCOMING -> MsgSide.IN
            }
            val state = when (item.status) {
                TransferStatus.Completed -> MsgState.DELIVERED
                is TransferStatus.Failed, TransferStatus.Canceled -> MsgState.FAILED
                TransferStatus.Pending, TransferStatus.WaitingApproval, is TransferStatus.Transferring -> MsgState.SENT
            }
            when (val kind = item.kind) {
                is HistoryKind.Text -> MockMessage(
                    id = item.id.toString(),
                    side = side,
                    kind = MsgKind.TEXT,
                    time = timeFmt.format(Date(item.createdAt)),
                    text = kind.content,
                    state = state,
                )
                is HistoryKind.File -> {
                    val progress = when (val status = item.status) {
                        is TransferStatus.Transferring ->
                            if (status.bytesTotal > 0) ((status.bytesDone * 100) / status.bytesTotal).toInt() else null
                        else -> null
                    }
                    MockMessage(
                        id = item.id.toString(),
                        side = side,
                        kind = MsgKind.FILE,
                        time = timeFmt.format(Date(item.createdAt)),
                        fileName = kind.name,
                        fileSize = humanSize(kind.size),
                        fileExt = kind.name.substringAfterLast('.', "bin").lowercase(),
                        state = state,
                        progress = progress,
                    )
                }
            }
        }
