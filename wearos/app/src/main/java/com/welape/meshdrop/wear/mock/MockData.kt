package com.welape.meshdrop.wear.mock

import androidx.compose.ui.graphics.Color

data class MockDevice(
    val id: String,
    val who: String,
    val name: String,
    val kind: String,
    val os: String,
    val rtt: Int,
    val initials: String,
    val color: Color,
    val angleDeg: Float,
    val dist: Float = 0.5f,
)

data class MockFileOffer(
    val peer: String,
    val deviceName: String,
    val fileName: String,
    val fileSize: String,
    val ext: String,
    val note: String,
)

object Mock {
    val devices: List<MockDevice> = listOf(
        MockDevice("lily",   "李莉",   "Lily · MacBook",   "mac",     "macOS",  18, "LL", Color(0xFFFFB4A1), 35f,  0.55f),
        MockDevice("kun",    "坤",     "Kun · Pixel 8",    "android", "Pixel",  32, "K",  Color(0xFFB7E5C8), 110f, 0.78f),
        MockDevice("jiawei", "嘉伟",   "Jiawei · iPad",    "ipad",    "iPadOS", 14, "JW", Color(0xFFC7B8FF), 200f, 0.40f),
        MockDevice("mengxi", "孟茜",   "Meng Xi · iPhone", "ios",     "iOS",    26, "MX", Color(0xFFFFD970), 265f, 0.62f),
        MockDevice("dev01",  "工位机", "DEV-01 · Win 11",  "win",     "Win 11", 41, "D1", Color(0xFF9AD0FF), 320f, 0.88f),
    )

    val pendingOffer = MockFileOffer(
        peer = "李莉",
        deviceName = "Lily · MacBook",
        fileName = "规划文档_v0.3.pages",
        fileSize = "3.4 MB",
        ext = "pages",
        note = "改完了帮我看下 §2.3 那段",
    )
}
