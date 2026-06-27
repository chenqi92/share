package com.welape.meshdrop.mock

import androidx.compose.ui.graphics.Color
import com.welape.meshdrop.ui.theme.AvatarLilac
import com.welape.meshdrop.ui.theme.AvatarMint
import com.welape.meshdrop.ui.theme.AvatarPeach
import com.welape.meshdrop.ui.theme.AvatarSky
import com.welape.meshdrop.ui.theme.AvatarSun

/**
 * UI-FIRST 阶段所有静态展示数据。
 * 与 backend 完全解耦；下一轮接 [com.welape.meshdrop.transport.ShareEngine] 时再替换。
 */

enum class DeviceKind { MAC, IPHONE, IPAD, ANDROID, WIN, LINUX }

data class MockDevice(
    val id: String,
    val name: String,
    val who: String,
    val kind: DeviceKind,
    val dist: Float,         // 0..1，雷达极坐标
    val angleDeg: Int,       // 0..360
    val color: Color,
    val initials: String,
    val os: String,
    val rttMs: Int,
    val online: Boolean = true,
    val ip: String,
    /** 会话键：对端指纹（跨会话/离线稳定）。mock 样本留空。 */
    val fingerprint: String = "",
)

val MockDevices: List<MockDevice> = listOf(
    MockDevice(
        id = "lily", name = "Lily's MacBook", who = "李莉", kind = DeviceKind.MAC,
        dist = 0.55f, angleDeg = 35, color = AvatarPeach, initials = "LL",
        os = "macOS", rttMs = 18, ip = "192.168.1.18",
    ),
    MockDevice(
        id = "kun", name = "Kun · Pixel 8", who = "坤", kind = DeviceKind.ANDROID,
        dist = 0.78f, angleDeg = 110, color = AvatarMint, initials = "K",
        os = "Pixel", rttMs = 32, ip = "192.168.1.27",
    ),
    MockDevice(
        id = "jiawei", name = "Jiawei · iPad", who = "嘉伟", kind = DeviceKind.IPAD,
        dist = 0.40f, angleDeg = 200, color = AvatarLilac, initials = "JW",
        os = "iPadOS", rttMs = 14, ip = "192.168.1.31",
    ),
    MockDevice(
        id = "mengxi", name = "Meng Xi · iPhone", who = "孟茜", kind = DeviceKind.IPHONE,
        dist = 0.62f, angleDeg = 265, color = AvatarSun, initials = "MX",
        os = "iOS", rttMs = 26, ip = "192.168.1.45",
    ),
    MockDevice(
        id = "dev01", name = "DEV-01 · Win 11", who = "工位机", kind = DeviceKind.WIN,
        dist = 0.88f, angleDeg = 320, color = AvatarSky, initials = "D1",
        os = "Win 11", rttMs = 41, ip = "192.168.1.55",
    ),
)

// MARK: 历史

enum class HistoryDir { INCOMING, OUTGOING }
enum class HistoryStatus { DONE, TRANSFERRING, QUEUED, FAILED }

sealed interface HistoryKindMock {
    data class Image(val count: Int) : HistoryKindMock
    data class File(val name: String, val size: String, val ext: String, val progress: Int? = null) : HistoryKindMock
    data class Text(val content: String) : HistoryKindMock
}

data class MockHistoryItem(
    val id: String,
    val dir: HistoryDir,
    val peer: String,
    val time: String,
    val kind: HistoryKindMock,
    val status: HistoryStatus,
    /** 该条目对端的会话键（指纹），供历史页点开跳转会话用。 */
    val peerKey: String = "",
)

val MockHistory: List<MockHistoryItem> = listOf(
    MockHistoryItem("h6", HistoryDir.INCOMING, "孟茜", "14:18", HistoryKindMock.Image(2), HistoryStatus.DONE),
    MockHistoryItem("h5", HistoryDir.OUTGOING, "孟茜", "14:10", HistoryKindMock.File("设计稿_v3_final.fig", "14.2 MB", "fig"), HistoryStatus.DONE),
    MockHistoryItem("h4", HistoryDir.OUTGOING, "李莉", "14:09", HistoryKindMock.Text("改完了，整理一下发你 ↓"), HistoryStatus.DONE),
    MockHistoryItem("h3", HistoryDir.OUTGOING, "嘉伟", "14:08", HistoryKindMock.File("iOS-mocks-final.zip", "48.6 MB", "zip", progress = 67), HistoryStatus.TRANSFERRING),
    MockHistoryItem("h2", HistoryDir.INCOMING, "坤", "13:58", HistoryKindMock.File("IMG_4821~38.heic", "128 MB", "heic", progress = 12), HistoryStatus.TRANSFERRING),
    MockHistoryItem("h1", HistoryDir.OUTGOING, "李莉", "13:42", HistoryKindMock.File("demo-video.mp4", "512 MB", "mp4"), HistoryStatus.QUEUED),
)

// MARK: 配对 / 文件 offer

data class MockPendingPairing(
    val id: String = "pp-1",
    val peer: String = "李莉",
    val deviceName: String = "Lily's MacBook",
    val fingerprintGroups: List<String> = listOf("ZX8K", "L72M", "9FQ3", "7HD2", "M1P6", "QA8N", "KZ9R", "X3WF"),
    val pinCode: String = "8-2-4-1-3-7",
    val receivedAt: String = "8s ago",
)

val MockPendingPairingItem = MockPendingPairing()

data class MockPendingOffer(
    val id: String = "po-1",
    val peer: String = "嘉伟",
    val deviceName: String = "Jiawei · iPad",
    val fileName: String = "规划文档_v0.3.pages",
    val fileSize: String = "3.4 MB",
    val note: String = "改完了帮我看下第二章，特别是 §2.3 那段",
    val receivedAt: String = "just now",
)

val MockPendingOfferItem = MockPendingOffer()

// MARK: 剪贴板

enum class ClipKind { LINK, TEXT, CODE }

data class MockClip(
    val id: String,
    val who: String,
    val kind: ClipKind,
    val body: String,
    val ago: String,
    val lang: String? = null,
)

val MockClips: List<MockClip> = listOf(
    MockClip("cb1", "嘉伟", ClipKind.LINK, "https://internal.acme.io/specs/auth-v3", "8s"),
    MockClip("cb2", "孟茜", ClipKind.TEXT, "1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配", "12m"),
    MockClip("cb3", "李莉", ClipKind.CODE, "docker run --rm -v \$PWD:/app meshdrop/build:latest", "34m", lang = "sh"),
    MockClip("cb4", "坤", ClipKind.TEXT, "会议室 B 已订到 16:00-17:30", "1h"),
    MockClip("cb5", "我", ClipKind.LINK, "figma://file/Q8xK2/MeshDrop?node-id=42:108", "2h"),
)

// MARK: 传输

enum class TransferState { DONE, SENDING, RECEIVING, QUEUED, FAILED }

data class MockTransfer(
    val name: String,
    val size: String,
    val ext: String,
    val from: String,
    val to: String,
    val progress: Int,
    val state: TransferState,
    val speed: String? = null,
    val eta: String? = null,
    val id: String = "",
    /** 已接收完成项的本地落盘 file:// Uri — 用于 OPEN 按钮调 ACTION_VIEW。 */
    val savedFileUri: String? = null,
    /** 失败原因（校验失败 / 连接中断 / 对方拒收 …），仅 state == FAILED 时有值。 */
    val failReason: String? = null,
)

val MockTransfers: List<MockTransfer> = listOf(
    MockTransfer("设计稿_v3_final.fig", "14.2 MB", "fig", "我", "孟茜", 100, TransferState.DONE, eta = "00:08"),
    MockTransfer("iOS-mocks-final.zip", "48.6 MB", "zip", "我", "孟茜", 67, TransferState.SENDING, "8.4 MB/s", "00:02"),
    MockTransfer("spec_PRD_2026Q1.pdf", "2.1 MB", "pdf", "我", "嘉伟", 34, TransferState.SENDING, "3.1 MB/s", "00:01"),
    MockTransfer("IMG_4821~IMG_4838.heic", "128 MB · 18 张", "heic", "坤", "我", 12, TransferState.RECEIVING, "11.7 MB/s", "00:09"),
    MockTransfer("release-notes.md", "4.8 KB", "md", "我", "DEV-01", 100, TransferState.DONE, eta = "00:01"),
    MockTransfer("demo-video.mp4", "512 MB", "mp4", "我", "李莉", 0, TransferState.QUEUED),
)

// 速度柱状图（采样）
val MockUploadBars = listOf(3, 5, 8, 7, 9, 6, 11, 12, 14, 11, 10, 11, 12, 11)
val MockDownloadBars = listOf(8, 9, 7, 6, 5, 7, 10, 12, 11, 12, 11, 12, 11, 12)
val MockSessionBars = listOf(2, 3, 5, 4, 6, 8, 7, 9, 10, 12, 11, 12, 11, 12, 14)

// MARK: 本机信息（自卡）

data class MockMe(
    val name: String = "Pixel 8 · 我",
    val fingerprintGroups: List<String> = listOf("ZX8K", "L72M", "9FQ3", "7HD2"),
    val ip: String = "192.168.1.42",
    val os: String = "Android 14",
    val visibility: String = "可见 · VISIBLE",
)

val MockMeData = MockMe()

// MARK: 聊天消息（与孟茜对话流）

enum class MsgSide { IN, OUT }
enum class MsgKind { TEXT, FILE, IMAGE }
enum class MsgState { SENT, DELIVERED, FAILED }

data class MockMessage(
    val id: String,
    val side: MsgSide,
    val kind: MsgKind,
    val time: String,
    val text: String? = null,
    val fileName: String? = null,
    val fileSize: String? = null,
    val fileExt: String? = null,
    val state: MsgState = MsgState.DELIVERED,
    val progress: Int? = null,
)

val MockChatWithMengxi = listOf(
    MockMessage("m1", MsgSide.IN, MsgKind.TEXT, "14:02",
        text = "刚做完 PRD 草稿，发你看看 →"),
    MockMessage("m2", MsgSide.IN, MsgKind.FILE, "14:03",
        fileName = "spec_PRD_2026Q1.pdf", fileSize = "2.1 MB", fileExt = "pdf"),
    MockMessage("m3", MsgSide.OUT, MsgKind.TEXT, "14:05",
        text = "收到，§2.3 那段要不要再细化一下？"),
    MockMessage("m4", MsgSide.OUT, MsgKind.TEXT, "14:06",
        text = "我把改完的发你 👇"),
    MockMessage("m5", MsgSide.OUT, MsgKind.FILE, "14:10",
        fileName = "设计稿_v3_final.fig", fileSize = "14.2 MB", fileExt = "fig",
        state = MsgState.DELIVERED),
    MockMessage("m6", MsgSide.OUT, MsgKind.FILE, "14:11",
        fileName = "iOS-mocks-final.zip", fileSize = "48.6 MB", fileExt = "zip",
        state = MsgState.SENT, progress = 67),
    MockMessage("m7", MsgSide.IN, MsgKind.TEXT, "14:18",
        text = "完美，正在下载 ✓"),
)

// 聊天列表（与各设备的会话）
data class MockChatPreview(
    val deviceId: String,
    val lastSnippet: String,
    val lastTime: String,
    val unread: Int = 0,
    val isFile: Boolean = false,
    /** 对端显示名，设备离线（不在 devicesUi）时用它还原会话行抬头。 */
    val peerName: String = "",
)

fun MockDeviceById(id: String): MockDevice? = MockDevices.firstOrNull { it.id == id }

val MockChatPreviews = listOf(
    MockChatPreview("mengxi", "完美，正在下载 ✓", "14:18", unread = 2),
    MockChatPreview("jiawei", "iOS-mocks-final.zip · 67%", "14:08", isFile = true),
    MockChatPreview("kun", "IMG_4821~38.heic · 接收中", "13:58", unread = 1, isFile = true),
    MockChatPreview("lily", "改完了，整理一下发你 ↓", "13:42"),
    MockChatPreview("dev01", "release-notes.md · 已送达", "12:30", isFile = true),
)

// MARK: 信任列表（已配对设备）

data class MockTrustRecord(
    val deviceName: String,
    val owner: String,
    val os: String,
    val fingerprintGroups: List<String>,
    val pairedDays: Int,
    val lastSeen: String,
)

val MockTrustList = listOf(
    MockTrustRecord(
        deviceName = "Lily's MacBook", owner = "李莉", os = "macOS Sonoma",
        fingerprintGroups = listOf("ZX8K", "L72M", "9FQ3", "7HD2"),
        pairedDays = 42, lastSeen = "8m ago",
    ),
    MockTrustRecord(
        deviceName = "Jiawei · iPad", owner = "嘉伟", os = "iPadOS 18",
        fingerprintGroups = listOf("Q8WK", "M6N3", "2FXP", "8AD4"),
        pairedDays = 12, lastSeen = "just now",
    ),
    MockTrustRecord(
        deviceName = "Meng Xi · iPhone", owner = "孟茜", os = "iOS 18",
        fingerprintGroups = listOf("V3RN", "8KK4", "ZW7Q", "9P22"),
        pairedDays = 5, lastSeen = "刚刚",
    ),
    MockTrustRecord(
        deviceName = "DEV-01 · Win 11", owner = "工位机", os = "Win 11 23H2",
        fingerprintGroups = listOf("K3RM", "6QPN", "M8X2", "7YH5"),
        pairedDays = 88, lastSeen = "12m ago",
    ),
)
