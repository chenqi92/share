package com.welape.meshdrop.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material.icons.outlined.Radar
import androidx.compose.material.icons.outlined.SwapVert
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.R
import com.welape.meshdrop.mock.MockChatPreviews
import com.welape.meshdrop.mock.MockDevices
import com.welape.meshdrop.mock.MockHistory
import com.welape.meshdrop.data.TransferStatus
import com.welape.meshdrop.transport.ShareEngine
import com.welape.meshdrop.ui.components.MeshIconBtn
import com.welape.meshdrop.ui.sheets.DevicePickerSheet
import com.welape.meshdrop.ui.sheets.FileOfferSheet
import com.welape.meshdrop.ui.sheets.OnboardingSheet
import com.welape.meshdrop.ui.sheets.PairingSheet
import com.welape.meshdrop.ui.sheets.SendBottomSheet
import com.welape.meshdrop.ui.tabs.ChatDetailScreen
import com.welape.meshdrop.ui.tabs.ChatListScreen
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

@Composable
fun PhoneRoot(state: MeshAppState, engine: ShareEngine? = null) {
    val mesh = MeshTheme.colors
    var inChatDetail by remember { mutableStateOf(false) }
    var inHistory by remember { mutableStateOf(false) }

    val realDevicesRaw = engine?.devices?.collectAsState()?.value
    val realHistoryRaw = engine?.history?.collectAsState()?.value
    val pendingPairings = engine?.pendingPairings?.collectAsState()?.value ?: emptyList()
    val pendingFileOffers = engine?.pendingFileOffers?.collectAsState()?.value ?: emptyList()
    val isStarting = engine?.isStarting?.collectAsState()?.value ?: false
    val lastError = engine?.lastError?.collectAsState()?.value

    val unnamedFallback = stringResource(R.string.common_unnamed)
    val devicesUi = realDevicesRaw?.mapIndexed { i, d -> d.toUiDevice(i, unnamedFallback) }
        ?: if (engine == null) MockDevices else emptyList()
    val historyUi = realHistoryRaw?.map { it.toUiHistoryItem() }
        ?: if (engine == null) MockHistory else emptyList()
    val chatPreviewsUi = realHistoryRaw?.toChatPreviews()
        ?: if (engine == null) MockChatPreviews else emptyList()
    fun uiDeviceFor(id: String) = devicesUi.firstOrNull { it.id == id }
        ?: realHistoryRaw?.firstOrNull { it.peer.id == id }?.peer?.toUiDevice(fallbackName = unnamedFallback)

    // 角标：聊天 = 未读入站文本数，传输 = 进行中任务数（真实数据，引擎缺席时为 0）
    val chatUnread = (engine?.unreadByPeer?.collectAsState()?.value ?: emptyMap()).values.sum()
    val activeTransfers = realHistoryRaw?.count { it.status is TransferStatus.Transferring } ?: 0
    var promptedPairingId by remember { mutableStateOf<String?>(null) }
    var promptedOfferId by remember { mutableStateOf<String?>(null) }

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

    Box(modifier = Modifier.fillMaxSize().background(mesh.canvas)) {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f)) {
                when (state.tab) {
                    MeshTab.DISCOVER -> if (inChatDetail && state.openChatDeviceId != null) {
                        val chatId = state.openChatDeviceId!!
                        ChatDetailScreen(
                            deviceId = chatId,
                            onBack = { inChatDetail = false },
                            showDropOverlay = state.showDropOverlay,
                            device = uiDeviceFor(chatId),
                            messages = realHistoryRaw?.toChatMessages(chatId),
                            useMockFallback = engine == null,
                            onSendText = { text ->
                                realDevicesRaw?.firstOrNull { it.id == chatId }?.let { engine?.sendText(it, text) }
                            },
                            onAttachFile = { state.sheet = MeshSheet.SEND },
                        )
                    } else {
                        DiscoverScreen(
                            selectedId = state.selectedDeviceId,
                            onSelect = { state.selectedDeviceId = it },
                            onTapDevice = {
                                state.openChatDeviceId = it
                                inChatDetail = true
                                engine?.markRead(it)
                            },
                            devices = devicesUi,
                            isStarting = isStarting,
                            lastError = lastError,
                            onDismissError = { engine?.clearLastError() },
                        )
                    }
                    MeshTab.CHAT -> if (inChatDetail && state.openChatDeviceId != null) {
                        val chatId = state.openChatDeviceId!!
                        ChatDetailScreen(
                            deviceId = chatId,
                            onBack = { inChatDetail = false },
                            showDropOverlay = state.showDropOverlay,
                            device = uiDeviceFor(chatId),
                            messages = realHistoryRaw?.toChatMessages(chatId),
                            useMockFallback = engine == null,
                            onSendText = { text ->
                                realDevicesRaw?.firstOrNull { it.id == chatId }?.let { engine?.sendText(it, text) }
                            },
                            onAttachFile = { state.sheet = MeshSheet.SEND },
                        )
                    } else {
                        ChatListScreen(
                            onOpenChat = {
                                state.openChatDeviceId = it
                                inChatDetail = true
                                engine?.markRead(it)
                            },
                            previews = chatPreviewsUi,
                            devices = devicesUi,
                        )
                    }
                    MeshTab.TRANSFER -> TransferScreen(engine = engine)
                    MeshTab.CLIPBOARD -> ClipboardScreen(engine = engine)
                    MeshTab.ME -> if (inHistory) {
                        HistoryPane(items = historyUi, onBack = { inHistory = false })
                    } else {
                        MeScreen(
                            onOpenPairing = { state.sheet = MeshSheet.PAIRING },
                            onOpenOnboarding = { state.sheet = MeshSheet.ONBOARDING },
                            onOpenHistory = { inHistory = true },
                            engine = engine,
                        )
                    }
                }

                // FAB
                if (!inChatDetail && state.tab == MeshTab.DISCOVER) {
                    Box(
                        Modifier
                            .align(Alignment.BottomEnd)
                            .padding(end = 24.dp, bottom = 24.dp),
                    ) {
                        Box(
                            Modifier
                                .size(64.dp)
                                .clip(CircleShape)
                                .background(Lime),
                            contentAlignment = Alignment.Center,
                        ) {
                            MeshIconBtn(
                                icon = Icons.Outlined.Add,
                                contentDescription = stringResource(R.string.common_send),
                                sizeDp = 64.dp,
                                accent = true,
                                onClick = { state.sheet = MeshSheet.SEND },
                            )
                        }
                    }
                }
            }
            BottomNavBar(state = state, chatUnread = chatUnread, activeTransfers = activeTransfers, onPickTab = {
                state.tab = it
                inChatDetail = false
                inHistory = false
            })
        }

        var pendingDraft by remember { mutableStateOf("") }
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

/** 历史页：带返回头的 [HistoryScreen] 包装，从「我」页进入，使 §4 必备的历史页在真实导航中可达。 */
@Composable
private fun HistoryPane(
    items: List<com.welape.meshdrop.mock.MockHistoryItem>,
    onBack: () -> Unit,
) {
    val mesh = MeshTheme.colors
    Column(modifier = Modifier.fillMaxSize().background(mesh.canvas)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(mesh.canvas)
                .padding(start = 12.dp, end = 20.dp, top = 12.dp, bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            MeshIconBtn(
                icon = Icons.Outlined.ArrowBack,
                contentDescription = stringResource(R.string.common_back),
                bordered = true,
                sizeDp = 36.dp,
                onClick = onBack,
            )
            Spacer(Modifier.weight(1f))
        }
        Box(modifier = Modifier.weight(1f)) {
            HistoryScreen(items = items)
        }
    }
}

@Composable
fun BottomNavBar(
    state: MeshAppState,
    chatUnread: Int = 0,
    activeTransfers: Int = 0,
    onPickTab: (MeshTab) -> Unit,
) {
    val mesh = MeshTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(mesh.surface)
            .padding(PaddingValues(horizontal = 8.dp, vertical = 6.dp)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        val tabs = listOf(
            Triple(MeshTab.DISCOVER, Icons.Outlined.Radar, stringResource(R.string.nav_discovery)),
            Triple(MeshTab.CHAT, Icons.Outlined.ChatBubbleOutline, stringResource(R.string.nav_chat)),
            Triple(MeshTab.TRANSFER, Icons.Outlined.SwapVert, stringResource(R.string.nav_transfer)),
            Triple(MeshTab.ME, Icons.Outlined.Person, stringResource(R.string.nav_me)),
        )
        tabs.forEach { (tab, icon, label) ->
            NavTabItem(
                icon = icon,
                label = label,
                badge = when (tab) {
                    MeshTab.CHAT -> chatUnread
                    MeshTab.TRANSFER -> activeTransfers
                    else -> 0
                },
                selected = state.tab == tab,
                onClick = { onPickTab(tab) },
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun NavTabItem(
    icon: ImageVector,
    label: String,
    badge: Int,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val mesh = MeshTheme.colors
    val bg = if (selected) mesh.limeFill else Color.Transparent
    val fg = if (selected) Ink else mesh.textSecondary
    Box(
        modifier = modifier
            .height(64.dp)
            .padding(horizontal = 4.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(bg),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Box(contentAlignment = Alignment.TopEnd) {
                Icon(imageVector = icon, contentDescription = label, tint = fg, modifier = Modifier.size(22.dp))
                if (badge > 0) {
                    Box(
                        Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(MeshTheme.colors.flame),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            text = badge.toString(),
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W700,
                                fontSize = 8.sp, color = androidx.compose.ui.graphics.Color.White,
                            ),
                        )
                    }
                }
            }
            Spacer(Modifier.height(4.dp))
            Text(
                text = label,
                style = TextStyle(
                    fontFamily = Geist, fontWeight = if (selected) FontWeight.W700 else FontWeight.W500,
                    fontSize = 10.sp, color = fg, letterSpacing = 0.4.sp,
                ),
            )
        }
    }
}
