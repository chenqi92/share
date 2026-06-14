package com.welape.meshdrop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Radar
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.SwapVert
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.welape.meshdrop.mock.MockChatPreview
import com.welape.meshdrop.mock.MockChatPreviews
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.mock.MockDeviceById
import com.welape.meshdrop.mock.MockDevices
import com.welape.meshdrop.mock.MockHistory
import com.welape.meshdrop.mock.MockMeData
import com.welape.meshdrop.transport.ShareEngine
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.MeshAvatar
import com.welape.meshdrop.ui.components.MeshDropLockup
import com.welape.meshdrop.ui.components.MeshDropMark
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.components.OnlineDot
import com.welape.meshdrop.ui.sheets.DevicePickerSheet
import com.welape.meshdrop.ui.sheets.FileOfferSheet
import com.welape.meshdrop.ui.sheets.OnboardingSheet
import com.welape.meshdrop.ui.sheets.PairingSheet
import com.welape.meshdrop.ui.sheets.SendBottomSheet
import com.welape.meshdrop.ui.tabs.ChatDetailScreen
import com.welape.meshdrop.ui.tabs.ClipboardScreen
import com.welape.meshdrop.ui.tabs.DiscoverScreen
import com.welape.meshdrop.ui.tabs.HistoryScreen
import com.welape.meshdrop.ui.tabs.MeScreen
import com.welape.meshdrop.ui.tabs.TransferScreen
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

/**
 * Tablet 双栏：左 NavRail + 中间 ChatList / Device list，右侧主内容 ChatDetail。
 * 横屏 / 大屏（WindowWidthSizeClass.Expanded / Medium）使用此布局。
 */
@Composable
fun TabletRoot(state: MeshAppState, engine: ShareEngine? = null) {
    val mesh = MeshTheme.colors

    val realDevicesRaw = engine?.devices?.collectAsState()?.value
    val realHistoryRaw = engine?.history?.collectAsState()?.value
    val pendingPairings = engine?.pendingPairings?.collectAsState()?.value ?: emptyList()
    val pendingFileOffers = engine?.pendingFileOffers?.collectAsState()?.value ?: emptyList()
    val isStarting = engine?.isStarting?.collectAsState()?.value ?: false
    val lastError = engine?.lastError?.collectAsState()?.value

    val devicesUi = realDevicesRaw?.mapIndexed { i, d -> d.toUiDevice(i) }
        ?: if (engine == null) MockDevices else emptyList()
    val chatPreviewsUi: List<MockChatPreview> = realHistoryRaw?.toChatPreviews()
        ?: if (engine == null) MockChatPreviews else emptyList()
    val historyUi = realHistoryRaw?.map { it.toUiHistoryItem() }
        ?: if (engine == null) MockHistory else emptyList()
    fun uiDeviceFor(id: String) = devicesUi.firstOrNull { it.id == id }
        ?: realHistoryRaw?.firstOrNull { it.peer.id == id }?.peer?.toUiDevice()

    var pendingDraft by remember { mutableStateOf("") }
    var promptedPairingId by remember { mutableStateOf<String?>(null) }
    var promptedOfferId by remember { mutableStateOf<String?>(null) }
    var inHistory by remember { mutableStateOf(false) }
    // 离开「我」页时退出历史子页，下次回到「我」从设置页起步。
    LaunchedEffect(state.tab) { if (state.tab != MeshTab.ME) inHistory = false }

    LaunchedEffect(
        pendingPairings.firstOrNull()?.id,
        pendingFileOffers.firstOrNull()?.id,
        state.sheet,
    ) {
        if (state.sheet != MeshSheet.NONE) return@LaunchedEffect
        val pairing = pendingPairings.firstOrNull()
        val offer = pendingFileOffers.firstOrNull()
        when {
            pairing != null && pairing.id.toString() != promptedPairingId -> {
                promptedPairingId = pairing.id.toString()
                state.sheet = MeshSheet.PAIRING
            }
            offer != null && offer.id.toString() != promptedOfferId -> {
                promptedOfferId = offer.id.toString()
                state.sheet = MeshSheet.FILE_OFFER
            }
        }
    }

    Row(modifier = Modifier.fillMaxSize().background(mesh.canvas)) {
        NavRail(state = state)
        Box(
            Modifier
                .fillMaxHeight()
                .width(1.dp)
                .background(mesh.divider),
        )
        // 中栏：会话/设备列表
        Column(
            modifier = Modifier
                .width(320.dp)
                .fillMaxHeight()
                .background(mesh.surface)
                .padding(top = 16.dp),
        ) {
            MiddlePanel(
                state,
                previews = chatPreviewsUi,
                devices = devicesUi,
                selfName = engine?.displayName ?: MockMeData.name,
                selfSubtitle = engine?.let { "${it.identity.id.take(8)} · LAN" }
                    ?: "${MockMeData.os} · ${MockMeData.ip}",
            )
        }
        Box(
            Modifier
                .fillMaxHeight()
                .width(1.dp)
                .background(mesh.divider),
        )
        // 右栏：主内容
        Box(modifier = Modifier.weight(1f).fillMaxHeight()) {
            when (state.tab) {
                MeshTab.DISCOVER -> DiscoverScreen(
                    selectedId = state.selectedDeviceId,
                    onSelect = { state.selectedDeviceId = it },
                    onTapDevice = { state.openChatDeviceId = it; state.tab = MeshTab.CHAT },
                    devices = devicesUi,
                    isStarting = isStarting,
                    lastError = lastError,
                    onDismissError = { engine?.clearLastError() },
                )
                MeshTab.CHAT -> state.openChatDeviceId?.let { id ->
                    ChatDetailScreen(
                        deviceId = id,
                        onBack = null,
                        showDropOverlay = state.showDropOverlay,
                        device = uiDeviceFor(id),
                        messages = realHistoryRaw?.toChatMessages(id),
                        useMockFallback = engine == null,
                        onSendText = { text ->
                            realDevicesRaw?.firstOrNull { it.id == id }?.let { engine?.sendText(it, text) }
                        },
                        onAttachFile = { state.sheet = MeshSheet.SEND },
                    )
                }
                MeshTab.TRANSFER -> TransferScreen(engine = engine)
                MeshTab.CLIPBOARD -> ClipboardScreen(engine = engine)
                MeshTab.ME -> if (inHistory) {
                    HistoryScreen(items = historyUi)
                } else {
                    MeScreen(
                        onOpenPairing = { state.sheet = MeshSheet.PAIRING },
                        onOpenOnboarding = { state.sheet = MeshSheet.ONBOARDING },
                        onOpenHistory = { inHistory = true },
                        engine = engine,
                    )
                }
            }
        }

        when (state.sheet) {
            MeshSheet.SEND -> SendBottomSheet(
                onDismiss = { state.sheet = MeshSheet.NONE },
                onPickDevices = { state.sheet = MeshSheet.PICKER },
                onSendTextDraft = { pendingDraft = it },
            )
            MeshSheet.PICKER -> DevicePickerSheet(
                state = state,
                onClose = { state.sheet = MeshSheet.NONE },
                devices = devicesUi,
                onSendToSelected = { picked ->
                    val draft = pendingDraft
                    if (draft.isNotBlank() && engine != null) {
                        val byId = (realDevicesRaw ?: emptyList()).associateBy { it.id }
                        picked.forEach { ui ->
                            byId[ui.id]?.let { engine.sendText(it, draft) }
                        }
                        pendingDraft = ""
                    }
                },
            )
            MeshSheet.PAIRING -> {
                val pairing = pendingPairings.firstOrNull()
                PairingSheet(
                    pairing = pairing,
                    useMockFallback = engine == null,
                    onDecision = { decision -> pairing?.id?.let { engine?.respondToPairing(it, decision) } },
                    onClose = { state.sheet = MeshSheet.NONE },
                )
            }
            MeshSheet.FILE_OFFER -> {
                val offer = pendingFileOffers.firstOrNull()
                FileOfferSheet(
                    offer = offer,
                    useMockFallback = engine == null,
                    onRespond = { accept -> offer?.id?.let { engine?.respondToFileOffer(it, accept) } },
                    onClose = { state.sheet = MeshSheet.NONE },
                )
            }
            MeshSheet.ONBOARDING -> OnboardingSheet(onClose = { state.sheet = MeshSheet.NONE })
            MeshSheet.NONE -> Unit
        }
    }
}

@Composable
private fun NavRail(state: MeshAppState) {
    val mesh = MeshTheme.colors
    Column(
        modifier = Modifier
            .width(88.dp)
            .fillMaxHeight()
            .background(mesh.surface)
            .padding(vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        MeshDropMark(size = 30.dp)
        Spacer(Modifier.height(18.dp))
        val items = listOf(
            Triple(MeshTab.DISCOVER, Icons.Outlined.Radar, "附近"),
            Triple(MeshTab.CHAT, Icons.Outlined.ChatBubbleOutline, "消息"),
            Triple(MeshTab.TRANSFER, Icons.Outlined.SwapVert, "传输"),
            Triple(MeshTab.ME, Icons.Outlined.Person, "我"),
        )
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items.forEach { (tab, icon, label) ->
                RailItem(icon = icon, label = label,
                    selected = state.tab == tab,
                    onClick = { state.tab = tab })
            }
        }
        Spacer(Modifier.weight(1f))
        // 底部 FAB
        Box(
            Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(Lime)
                .clickable { state.sheet = MeshSheet.SEND },
            contentAlignment = Alignment.Center,
        ) {
            Icon(imageVector = Icons.Outlined.Add, contentDescription = "发送", tint = Ink, modifier = Modifier.size(28.dp))
        }
        Spacer(Modifier.height(8.dp))
        MonoLabel("LAN")
    }
}

@Composable
private fun RailItem(icon: ImageVector, label: String, selected: Boolean, onClick: () -> Unit) {
    val mesh = MeshTheme.colors
    val bg = if (selected) mesh.limeFill else Color.Transparent
    val fg = if (selected) Ink else mesh.textSecondary
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .width(72.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(PaddingValues(vertical = 10.dp)),
    ) {
        Icon(imageVector = icon, contentDescription = label, tint = fg, modifier = Modifier.size(22.dp))
        Spacer(Modifier.height(4.dp))
        Text(
            text = label,
            style = TextStyle(
                fontFamily = Geist, fontWeight = if (selected) FontWeight.W700 else FontWeight.W500,
                fontSize = 11.sp, color = fg,
            ),
        )
    }
}

@Composable
private fun MiddlePanel(
    state: MeshAppState,
    previews: List<MockChatPreview> = MockChatPreviews,
    devices: List<MockDevice> = MockDevices,
    selfName: String = MockMeData.name,
    selfSubtitle: String = "${MockMeData.os} · ${MockMeData.ip}",
) {
    val mesh = MeshTheme.colors
    val byId = devices.associateBy { it.id }
    Column(modifier = Modifier.padding(horizontal = 14.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            MeshDropLockup(markSize = 22.dp, fontSize = 18.sp)
            Spacer(Modifier.weight(1f))
            Icon(Icons.Outlined.Settings, contentDescription = "设置", tint = mesh.textTertiary, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.height(8.dp))
        // 自卡
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .border(1.dp, mesh.outline, RoundedCornerShape(12.dp))
                .background(mesh.card)
                .padding(PaddingValues(horizontal = 12.dp, vertical = 10.dp)),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(contentAlignment = Alignment.BottomEnd) {
                MeshAvatar(initials = "我", color = com.welape.meshdrop.ui.theme.AvatarMint, sizeDp = 32, ringColor = Lime)
                Box(Modifier.size(10.dp)) { OnlineDot(sizeDp = 9) }
            }
            Spacer(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(selfName, style = TextStyle(fontFamily = Geist, fontWeight = FontWeight.W700, fontSize = 13.sp, color = mesh.textPrimary))
                Text(selfSubtitle, style = TextStyle(fontFamily = GeistMono, fontSize = 10.sp, color = mesh.textTertiary))
            }
        }

        AsciiDivider(label = "会话 · CONVERSATIONS · ${previews.size}")

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            previews.forEach { chat ->
                val device = byId[chat.deviceId] ?: MockDeviceById(chat.deviceId) ?: return@forEach
                val isSelected = state.openChatDeviceId == chat.deviceId
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .border(1.dp, if (isSelected) Lime else mesh.outline, RoundedCornerShape(12.dp))
                        .background(if (isSelected) mesh.limeFill else mesh.card)
                        .clickable {
                            state.openChatDeviceId = chat.deviceId
                            state.tab = MeshTab.CHAT
                        }
                        .padding(PaddingValues(horizontal = 10.dp, vertical = 10.dp)),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(contentAlignment = Alignment.BottomEnd) {
                        MeshAvatar(initials = device.initials, color = device.color, sizeDp = 36)
                        if (device.online) Box(Modifier.size(11.dp)) { OnlineDot(sizeDp = 9) }
                    }
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(device.who, style = TextStyle(fontFamily = Geist, fontWeight = FontWeight.W700, fontSize = 13.sp, color = mesh.textPrimary))
                        Text(chat.lastSnippet, style = TextStyle(fontFamily = Geist, fontSize = 11.sp, color = mesh.textSecondary), maxLines = 1)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(chat.lastTime, style = TextStyle(fontFamily = GeistMono, fontSize = 9.sp, color = mesh.textTertiary))
                        if (chat.unread > 0) {
                            Spacer(Modifier.height(4.dp))
                            Box(
                                Modifier.size(16.dp).clip(CircleShape).background(Lime),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(chat.unread.toString(), style = TextStyle(fontFamily = GeistMono, fontSize = 9.sp, fontWeight = FontWeight.W700, color = Ink))
                            }
                        }
                    }
                }
            }
        }
    }
}
