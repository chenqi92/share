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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import com.welape.meshdrop.transport.ShareEngine
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.welape.meshdrop.R
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.widget.Toast
import com.welape.meshdrop.data.IdentityStore
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
    onOpenHistory: () -> Unit = {},
    engine: ShareEngine? = null,
) {
    val mesh = MeshTheme.colors
    val context = LocalContext.current
    var showResetDialog by remember { mutableStateOf(false) }

    // 真实身份优先；引擎缺席（纯 preview）时回落 mock 文案。
    val fingerprintGroups = engine?.identity?.fingerprint?.let { groupFingerprint(it) }
        ?: MockMeData.fingerprintGroups
    val selfName = engine?.displayName ?: MockMeData.name
    val selfSubtitle = engine?.let { stringResource(R.string.me_fp_below, it.identity.id.take(8)) } ?: "${MockMeData.os} · ${MockMeData.ip}"
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
                MeshAvatar(initials = stringResource(R.string.me_self_initials), color = AvatarMint, sizeDp = 56, ringColor = Lime)
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        selfName,
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 20.sp, color = mesh.textPrimary,
                        ),
                    )
                    Text(
                        selfSubtitle,
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W500,
                            fontSize = 11.sp, color = mesh.textTertiary,
                        ),
                    )
                }
                MeshChip(text = stringResource(R.string.me_visibility_chip), tone = ChipTone.LIME, mono = true)
            }
            Spacer(Modifier.height(14.dp))
            FingerprintRow(fingerprintGroups)
        }

        AsciiDivider(label = stringResource(R.string.me_section_library))
        SettingsCard {
            ChevronRow(
                title = stringResource(R.string.me_history_title),
                subtitle = stringResource(R.string.me_history_subtitle),
                onClick = onOpenHistory,
            )
        }

        AsciiDivider(label = stringResource(R.string.me_section_visibility))
        SettingsCard {
            SwitchRow(title = stringResource(R.string.me_visible_in_nearby), subtitle = stringResource(R.string.me_visible_in_nearby_sub), initial = true)
            DividerThin()
            SwitchRow(title = stringResource(R.string.me_allow_stranger_pairing), subtitle = stringResource(R.string.me_allow_stranger_pairing_sub), initial = true)
            DividerThin()
            SwitchRow(title = stringResource(R.string.me_vibrate_on_receive), subtitle = stringResource(R.string.me_vibrate_on_receive_sub), initial = false)
            if (engine != null) {
                DividerThin()
                val autoAccept = engine.autoAcceptFromTrusted.collectAsState().value
                SwitchRow(
                    title = stringResource(R.string.me_auto_accept),
                    subtitle = stringResource(R.string.me_auto_accept_sub),
                    checked = autoAccept,
                    onChange = { engine.setAutoAcceptFromTrusted(it) },
                )
            }
        }

        AsciiDivider(label = stringResource(R.string.me_section_security))
        SettingsCard {
            ChevronRow(title = stringResource(R.string.me_paired_devices), subtitle = stringResource(R.string.me_paired_devices_sub, MockTrustList.size))
            DividerThin()
            ChevronRow(title = stringResource(R.string.me_my_fingerprint), subtitle = fingerprintGroups.joinToString(" · "))
            DividerThin()
            ChevronRow(title = stringResource(R.string.me_scan_pair), subtitle = stringResource(R.string.me_scan_pair_sub), onClick = onOpenPairing)
            DividerThin()
            ChevronRow(
                title = stringResource(R.string.me_reset_identity),
                subtitle = stringResource(R.string.me_reset_identity_sub),
                onClick = { showResetDialog = true },
            )
        }

        if (showResetDialog) {
            AlertDialog(
                onDismissRequest = { showResetDialog = false },
                title = { Text(stringResource(R.string.me_reset_dialog_title)) },
                text = {
                    Text(stringResource(R.string.me_reset_dialog_body))
                },
                confirmButton = {
                    TextButton(onClick = {
                        IdentityStore.reset(context)
                        Toast.makeText(context, context.getString(R.string.me_reset_toast), Toast.LENGTH_LONG).show()
                        showResetDialog = false
                    }) { Text(stringResource(R.string.me_reset_confirm)) }
                },
                dismissButton = {
                    TextButton(onClick = { showResetDialog = false }) { Text(stringResource(R.string.common_cancel)) }
                },
            )
        }

        AsciiDivider(label = stringResource(R.string.me_section_trust))
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
                MonoLabel(stringResource(R.string.me_trust_col_device))
                Spacer(Modifier.weight(1f))
                MonoLabel(stringResource(R.string.me_trust_col_fingerprint))
                Spacer(Modifier.width(56.dp))
                MonoLabel(stringResource(R.string.me_trust_col_action))
            }
            DividerThin()
            MockTrustList.forEachIndexed { idx, rec ->
                TrustRow(rec)
                if (idx != MockTrustList.lastIndex) DividerThin()
            }
        }

        AsciiDivider(label = stringResource(R.string.me_section_about))
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
                        stringResource(R.string.me_about_version),
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 16.sp, color = mesh.textPrimary,
                        ),
                    )
                    Text(
                        stringResource(R.string.me_about_fonts),
                        style = TextStyle(
                            fontFamily = GeistMono, fontWeight = FontWeight.W500,
                            fontSize = 10.sp, color = mesh.textTertiary, letterSpacing = 0.6.sp,
                        ),
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(
                stringResource(R.string.me_about_tagline),
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W400,
                    fontSize = 12.sp, color = mesh.textSecondary,
                ),
            )
        }

        Spacer(Modifier.height(80.dp))
    }
}

/** 32 位 hex 指纹 → 4 字符分组、大写（设计宪法：指纹 4 字符分组大写）。 */
private fun groupFingerprint(fp: String): List<String> =
    fp.uppercase().chunked(4)

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

/** 受控版：值与回调由外部持有（绑定到引擎设置）。 */
@Composable
private fun SwitchRow(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    val mesh = MeshTheme.colors
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
            onCheckedChange = onChange,
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
                stringResource(R.string.me_trust_revoke),
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
