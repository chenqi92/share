package com.welape.meshdrop.ui.tabs

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockMeData
import com.welape.meshdrop.mock.MockTrustList
import com.welape.meshdrop.mock.MockTrustRecord
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.MeshAvatar
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.MeshDropMark
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.theme.AvatarMint
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@Composable
fun MeScreen(
    onOpenPairing: () -> Unit = {},
    onOpenOnboarding: () -> Unit = {},
) {
    val mesh = MeshTheme.colors
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(mesh.canvas)
            .verticalScroll(rememberScrollState())
            .padding(PaddingValues(horizontal = 20.dp)),
    ) {
        Spacer(Modifier.height(20.dp))

        // 自卡
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .border(1.dp, mesh.outline, RoundedCornerShape(18.dp))
                .background(mesh.card)
                .padding(PaddingValues(horizontal = 18.dp, vertical = 18.dp)),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                MeshAvatar(initials = "我", color = AvatarMint, sizeDp = 56, ringColor = Lime)
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        MockMeData.name,
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 20.sp, color = mesh.textPrimary,
                        ),
                    )
                    Text(
                        "${MockMeData.os} · ${MockMeData.ip}",
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W500,
                            fontSize = 11.sp, color = mesh.textTertiary,
                        ),
                    )
                }
                MeshChip(text = MockMeData.visibility, tone = ChipTone.LIME, mono = true)
            }
            Spacer(Modifier.height(14.dp))
            FingerprintRow(MockMeData.fingerprintGroups)
        }

        AsciiDivider(label = "可见性 · VISIBILITY")
        SettingsCard {
            SwitchRow(title = "在 Nearby 中显示我", subtitle = "其他设备能看到本机", initial = true)
            DividerThin()
            SwitchRow(title = "允许陌生设备发起配对", subtitle = "首次会弹出 6 字符代码确认", initial = true)
            DividerThin()
            SwitchRow(title = "接收时震动", subtitle = "incoming · vibrate", initial = false)
        }

        AsciiDivider(label = "安全 · SECURITY · E2E")
        SettingsCard {
            ChevronRow(title = "已配对设备", subtitle = "${MockTrustList.size} 台 · 可单独撤销")
            DividerThin()
            ChevronRow(title = "我的指纹", subtitle = "ZX8K · L72M · 9FQ3 · 7HD2")
            DividerThin()
            ChevronRow(title = "扫码 / 6 字符配对", subtitle = "向新设备发起", onClick = onOpenPairing)
        }

        AsciiDivider(label = "信任管理 · TRUST MANAGER")
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .border(1.dp, mesh.outline, RoundedCornerShape(18.dp))
                .background(mesh.card),
        ) {
            // 表头
            Row(
                modifier = Modifier.padding(PaddingValues(horizontal = 14.dp, vertical = 12.dp)),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                MonoLabel("DEVICE")
                Spacer(Modifier.weight(1f))
                MonoLabel("FINGERPRINT")
                Spacer(Modifier.width(56.dp))
                MonoLabel("ACTION")
            }
            DividerThin()
            MockTrustList.forEachIndexed { idx, rec ->
                TrustRow(rec)
                if (idx != MockTrustList.lastIndex) DividerThin()
            }
        }

        AsciiDivider(label = "关于 · ABOUT")
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .border(1.dp, mesh.outline, RoundedCornerShape(18.dp))
                .background(mesh.card)
                .clickable { onOpenOnboarding() }
                .padding(PaddingValues(horizontal = 18.dp, vertical = 18.dp)),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                MeshDropMark(size = 28.dp)
                Column {
                    Text(
                        "meshdrop · v0.1.0",
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 16.sp, color = mesh.textPrimary,
                        ),
                    )
                    Text(
                        "Space Grotesk · Geist · Geist Mono",
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W500,
                            fontSize = 10.sp, color = mesh.textTertiary, letterSpacing = 0.6.sp,
                        ),
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(
                "An intranet drop · radar discovery · drag-to-send · E2E encryption",
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W400,
                    fontSize = 12.sp, color = mesh.textSecondary,
                ),
            )
        }

        Spacer(Modifier.height(80.dp))
    }
}

@Composable
private fun FingerprintRow(groups: List<String>) {
    val mesh = MeshTheme.colors
    Row(verticalAlignment = Alignment.CenterVertically) {
        MonoLabel("FP")
        Spacer(Modifier.width(8.dp))
        Text(
            text = groups.joinToString("  ·  "),
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W700,
                fontSize = 13.sp, color = mesh.textPrimary, letterSpacing = 1.2.sp,
            ),
        )
    }
}

@Composable
private fun SettingsCard(content: @Composable () -> Unit) {
    val mesh = MeshTheme.colors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .border(1.dp, mesh.outline, RoundedCornerShape(18.dp))
            .background(mesh.card),
    ) {
        content()
    }
}

@Composable
private fun SwitchRow(title: String, subtitle: String, initial: Boolean) {
    val mesh = MeshTheme.colors
    var checked by remember { mutableStateOf(initial) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(PaddingValues(horizontal = 16.dp, vertical = 12.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W600,
                    fontSize = 14.sp, color = mesh.textPrimary,
                ),
            )
            Text(
                subtitle,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = mesh.textTertiary,
                ),
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = { checked = it },
            colors = SwitchDefaults.colors(
                checkedThumbColor = Ink,
                checkedTrackColor = Lime,
                checkedBorderColor = LimeDeep,
                uncheckedThumbColor = mesh.textTertiary,
                uncheckedTrackColor = mesh.surface,
                uncheckedBorderColor = mesh.outline,
            ),
        )
    }
}

@Composable
private fun ChevronRow(title: String, subtitle: String, onClick: () -> Unit = {}) {
    val mesh = MeshTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(PaddingValues(horizontal = 16.dp, vertical = 12.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W600,
                    fontSize = 14.sp, color = mesh.textPrimary,
                ),
            )
            Text(
                subtitle,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = mesh.textTertiary,
                ),
            )
        }
        Text(
            "›",
            style = TextStyle(
                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W400,
                fontSize = 22.sp, color = mesh.textTertiary,
            ),
        )
    }
}

@Composable
private fun TrustRow(rec: MockTrustRecord) {
    val mesh = MeshTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(PaddingValues(horizontal = 14.dp, vertical = 12.dp)),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                rec.deviceName,
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W600,
                    fontSize = 13.sp, color = mesh.textPrimary,
                ),
            )
            Text(
                "${rec.owner} · ${rec.os} · ${rec.lastSeen}",
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 10.sp, color = mesh.textTertiary,
                ),
            )
        }
        Text(
            text = rec.fingerprintGroups.take(2).joinToString("·"),
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W700,
                fontSize = 11.sp, color = mesh.textSecondary, letterSpacing = 0.8.sp,
            ),
        )
        Spacer(Modifier.width(10.dp))
        Box(
            Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(Color.Transparent)
                .border(1.dp, mesh.outline, RoundedCornerShape(8.dp))
                .padding(PaddingValues(horizontal = 10.dp, vertical = 6.dp))
                .clickable { /* mock revoke */ },
        ) {
            Text(
                "撤销",
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W600,
                    fontSize = 11.sp, color = mesh.danger,
                ),
            )
        }
    }
}

@Composable
private fun DividerThin() {
    val mesh = MeshTheme.colors
    Box(
        Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(mesh.divider),
    )
}
