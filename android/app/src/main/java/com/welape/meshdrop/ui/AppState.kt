package com.welape.meshdrop.ui

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue

/** 单纯的 UI 端状态容器（mock 阶段，无业务依赖）。 */
class MeshAppState {
    /** 当前 Tab。 */
    var tab by mutableStateOf(MeshTab.DISCOVER)

    /** 当前打开的 ChatDetail 对应的设备 id。 */
    var openChatDeviceId by mutableStateOf<String?>(null)

    /** Discover 屏选中的设备（影响雷达高亮 + 长按状态）。 */
    var selectedDeviceId by mutableStateOf<String?>(null)

    /** 多选模式 (DevicePicker)。 */
    var multiSelectMode by mutableStateOf(false)
    val pickerSelection = mutableStateMapOf<String, Boolean>()

    /** 全局 sheet 控制。 */
    var sheet by mutableStateOf(MeshSheet.NONE)

    /** Demo overlay 开关：拖放浮层 / 收件浮窗 / heads-up。 */
    var showDropOverlay by mutableStateOf(false)
    var showReceivePopover by mutableStateOf(false)

    fun togglePicker(id: String) {
        pickerSelection[id] = !(pickerSelection[id] ?: false)
    }
}

enum class MeshTab(val label: String) {
    DISCOVER("附近 · Nearby"), CHAT("消息 · Chat"), TRANSFER("传输 · Transfer"),
    CLIPBOARD("剪贴板 · Clipboard"), ME("我 · Me"),
}

enum class MeshSheet { NONE, SEND, PICKER, PAIRING, FILE_OFFER, ONBOARDING }

@Composable
fun rememberMeshAppState(): MeshAppState = remember { MeshAppState() }

object Selections {
    @Composable
    fun rememberMultiSelectMode() = rememberSaveable { mutableStateOf(false) }
}
