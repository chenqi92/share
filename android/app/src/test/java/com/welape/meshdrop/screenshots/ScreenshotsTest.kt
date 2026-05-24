package com.welape.meshdrop.screenshots

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import app.cash.paparazzi.DeviceConfig
import app.cash.paparazzi.Paparazzi
import com.android.resources.NightMode
import com.welape.meshdrop.mock.MockDevices
import com.welape.meshdrop.ui.MeshAppState
import com.welape.meshdrop.ui.MeshSheet
import com.welape.meshdrop.ui.MeshTab
import com.welape.meshdrop.ui.PhoneRoot
import com.welape.meshdrop.ui.TabletRoot
import com.welape.meshdrop.ui.sheets.FileOfferSheetContent
import com.welape.meshdrop.ui.sheets.OnboardingSheetContent
import com.welape.meshdrop.ui.sheets.PairingSheetContent
import com.welape.meshdrop.ui.tabs.ChatDetailScreen
import com.welape.meshdrop.ui.tabs.HistoryScreen
import com.welape.meshdrop.ui.tabs.MeScreen
import com.welape.meshdrop.ui.theme.MeshDropTheme
import org.junit.Rule
import org.junit.Test

/**
 * 截图测试矩阵：
 * - Phone × {Light, Dark}：discovery / chatlist / chat / transfers / history / settings / trust /
 *   pairing / onboarding / receive / picker
 * - Tablet × {Light, Dark}：split / chat / transfers / history / settings
 * - Heads-up notification × {collapsed, expanded}（图片由静态 mock 替代，见 PR）
 */
class ScreenshotsTest {

    @get:Rule
    val paparazzi: Paparazzi = Paparazzi(
        deviceConfig = DeviceConfig.PIXEL_6.copy(softButtons = false),
        renderingMode = com.android.ide.common.rendering.api.SessionParams.RenderingMode.NORMAL,
    )

    private fun render(
        dark: Boolean,
        tablet: Boolean = false,
        content: @Composable () -> Unit,
    ) {
        paparazzi.unsafeUpdateConfig(
            deviceConfig = if (tablet) {
                DeviceConfig.PIXEL_C.copy(nightMode = if (dark) NightMode.NIGHT else NightMode.NOTNIGHT, softButtons = false)
            } else {
                DeviceConfig.PIXEL_6.copy(nightMode = if (dark) NightMode.NIGHT else NightMode.NOTNIGHT, softButtons = false)
            },
        )
        paparazzi.snapshot {
            MeshDropTheme(darkTheme = dark) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(if (dark) androidx.compose.ui.graphics.Color(0xFF0E0C09) else androidx.compose.ui.graphics.Color(0xFFF5F2EC)),
                ) { content() }
            }
        }
    }

    private fun phoneState(tab: MeshTab = MeshTab.DISCOVER, sheet: MeshSheet = MeshSheet.NONE): MeshAppState {
        return MeshAppState().apply {
            this.tab = tab
            this.sheet = sheet
            this.openChatDeviceId = "mengxi"
            this.pickerSelection["mengxi"] = true
            this.pickerSelection["lily"] = true
            this.pickerSelection["jiawei"] = false
            this.pickerSelection["kun"] = false
            this.pickerSelection["dev01"] = false
        }
    }

    // ───────── Phone ─────────

    @Test fun android_phone_discovery_light() = render(dark = false) { PhoneRoot(phoneState()) }
    @Test fun android_phone_discovery_dark()  = render(dark = true)  { PhoneRoot(phoneState()) }

    @Test fun android_phone_chatlist_light() = render(dark = false) { PhoneRoot(phoneState(MeshTab.CHAT)) }
    @Test fun android_phone_chatlist_dark()  = render(dark = true)  { PhoneRoot(phoneState(MeshTab.CHAT)) }

    @Test fun android_phone_chat_light() = render(dark = false) { ChatDetailScreen(deviceId = "mengxi", onBack = {}) }
    @Test fun android_phone_chat_dark()  = render(dark = true)  { ChatDetailScreen(deviceId = "mengxi", onBack = {}) }

    @Test fun android_phone_transfers_light() = render(dark = false) { PhoneRoot(phoneState(MeshTab.TRANSFER)) }
    @Test fun android_phone_transfers_dark()  = render(dark = true)  { PhoneRoot(phoneState(MeshTab.TRANSFER)) }

    @Test fun android_phone_history_light() = render(dark = false) { HistoryScreen() }
    @Test fun android_phone_history_dark()  = render(dark = true)  { HistoryScreen() }

    @Test fun android_phone_settings_light() = render(dark = false) { MeScreen() }
    @Test fun android_phone_settings_dark()  = render(dark = true)  { MeScreen() }

    @Test fun android_phone_trust_light() = render(dark = false) { MeScreen() }
    @Test fun android_phone_trust_dark()  = render(dark = true)  { MeScreen() }

    @Test fun android_phone_pairing_light() = render(dark = false) { PairingSheetContent() }
    @Test fun android_phone_pairing_dark()  = render(dark = true)  { PairingSheetContent() }

    @Test fun android_phone_onboarding_light() = render(dark = false) { OnboardingSheetContent() }
    @Test fun android_phone_onboarding_dark()  = render(dark = true)  { OnboardingSheetContent() }

    @Test fun android_phone_receive_light() = render(dark = false) { FileOfferSheetContent() }
    @Test fun android_phone_receive_dark()  = render(dark = true)  { FileOfferSheetContent() }

    @Test fun android_phone_picker_light() = render(dark = false) {
        com.welape.meshdrop.ui.sheets.DevicePickerSheet(state = phoneState().apply { sheet = MeshSheet.PICKER }, onClose = {})
    }
    @Test fun android_phone_picker_dark()  = render(dark = true) {
        com.welape.meshdrop.ui.sheets.DevicePickerSheet(state = phoneState().apply { sheet = MeshSheet.PICKER }, onClose = {})
    }

    // ───────── Tablet ─────────

    private fun tabletState(tab: MeshTab = MeshTab.CHAT): MeshAppState = MeshAppState().apply {
        this.tab = tab
        this.openChatDeviceId = "mengxi"
    }

    @Test fun android_tablet_split_light() = render(dark = false, tablet = true) { TabletRoot(tabletState(MeshTab.DISCOVER)) }
    @Test fun android_tablet_split_dark()  = render(dark = true, tablet = true)  { TabletRoot(tabletState(MeshTab.DISCOVER)) }

    @Test fun android_tablet_chat_light() = render(dark = false, tablet = true) { TabletRoot(tabletState(MeshTab.CHAT)) }
    @Test fun android_tablet_chat_dark()  = render(dark = true, tablet = true)  { TabletRoot(tabletState(MeshTab.CHAT)) }

    @Test fun android_tablet_transfers_light() = render(dark = false, tablet = true) { TabletRoot(tabletState(MeshTab.TRANSFER)) }
    @Test fun android_tablet_transfers_dark()  = render(dark = true, tablet = true)  { TabletRoot(tabletState(MeshTab.TRANSFER)) }

    @Test fun android_tablet_history_light() = render(dark = false, tablet = true) { TabletRoot(tabletState(MeshTab.ME)) }
    @Test fun android_tablet_history_dark()  = render(dark = true, tablet = true)  { TabletRoot(tabletState(MeshTab.ME)) }

    @Test fun android_tablet_settings_light() = render(dark = false, tablet = true) { TabletRoot(tabletState(MeshTab.ME)) }
    @Test fun android_tablet_settings_dark()  = render(dark = true, tablet = true)  { TabletRoot(tabletState(MeshTab.ME)) }

    // ───────── Heads-up notification mock ─────────

    @Test fun android_headsup_notif_collapsed() = render(dark = true) {
        com.welape.meshdrop.ui.notifications.HeadsUpMockCollapsed()
    }

    @Test fun android_headsup_notif_expanded() = render(dark = true) {
        com.welape.meshdrop.ui.notifications.HeadsUpMockExpanded()
    }
}
