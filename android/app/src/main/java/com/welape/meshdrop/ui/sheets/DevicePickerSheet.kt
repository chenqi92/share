package com.welape.meshdrop.ui.sheets

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.R
import com.welape.meshdrop.mock.MockDevice
import com.welape.meshdrop.mock.MockDevices
import com.welape.meshdrop.ui.MeshAppState
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.MeshAvatar
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.MeshIconBtn
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.components.Photo
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.Paper
import com.welape.meshdrop.ui.theme.SpaceGrotesk

/** 多选 DevicePicker：全屏，长按设备 row 进入此模式，底部 CTA bar。 */
@Composable
fun DevicePickerSheet(
    state: MeshAppState,
    onClose: () -> Unit,
    devices: List<MockDevice> = MockDevices,
    onSendToSelected: (List<MockDevice>) -> Unit = {},
) {
    val mesh = MeshTheme.colors
    val selected = state.pickerSelection.filterValues { it }.keys.toList()
    val selectedDevices = devices.filter { it.id in selected }

    Box(modifier = Modifier.fillMaxSize().background(mesh.canvas)) {
        Column(modifier = Modifier.fillMaxSize().padding(bottom = 96.dp)) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(PaddingValues(horizontal = 16.dp, vertical = 14.dp)),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                MeshIconBtn(icon = Icons.Outlined.Close, contentDescription = stringResource(R.string.picker_cancel), bordered = true, sizeDp = 36.dp, onClick = onClose)
                Spacer(Modifier.width(10.dp))
                Text(
                    stringResource(R.string.picker_cancel), style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W600,
                        fontSize = 15.sp, color = mesh.textPrimary,
                    ),
                )
                Spacer(Modifier.weight(1f))
                Text(
                    stringResource(R.string.picker_selected_count, selected.size),
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W700,
                        fontSize = 11.sp, color = mesh.textSecondary, letterSpacing = 1.2.sp,
                    ),
                )
            }

            Column(
                modifier = Modifier.padding(horizontal = 20.dp),
            ) {
                Text(
                    stringResource(R.string.picker_title),
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 26.sp, color = mesh.textPrimary, letterSpacing = (-0.5).sp,
                    ),
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    stringResource(R.string.picker_attachment_summary),
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = mesh.textTertiary,
                    ),
                )

                Spacer(Modifier.height(14.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Photo(sizeDp = 88.dp, hueDeg = 22)
                    Photo(sizeDp = 88.dp, hueDeg = 200)
                    Photo(sizeDp = 88.dp, hueDeg = 320)
                }

                AsciiDivider(label = stringResource(R.string.discovery_section_nearby, devices.size))

                // 3 列 grid
                val rows = devices.chunked(3)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    rows.forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            row.forEach { dev ->
                                PickerCell(
                                    initials = dev.initials,
                                    color = dev.color,
                                    name = dev.who,
                                    os = dev.os,
                                    selected = state.pickerSelection[dev.id] == true,
                                    modifier = Modifier.weight(1f),
                                    onClick = { state.togglePicker(dev.id) },
                                )
                            }
                            // 占位补齐 3 列
                            repeat(3 - row.size) {
                                Box(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }

        // 底部 CTA bar (ink 底)
        Row(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .background(mesh.textPrimary)
                .padding(PaddingValues(horizontal = 18.dp, vertical = 14.dp)),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    stringResource(R.string.picker_send_to_count, selected.size),
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 16.sp, color = Paper,
                    ),
                )
                Text(
                    selectedDevices.joinToString(" · ") { it.who }.ifEmpty { stringResource(R.string.picker_none_selected) },
                    style = TextStyle(
                        fontFamily = GeistMono, fontWeight = FontWeight.W500,
                        fontSize = 11.sp, color = Color(0xCCE8E3D6),
                    ),
                )
            }
            Box(
                Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(Lime)
                    .clickable {
                        if (selectedDevices.isNotEmpty()) onSendToSelected(selectedDevices)
                        onClose()
                    }
                    .padding(PaddingValues(horizontal = 18.dp, vertical = 12.dp)),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        stringResource(R.string.common_send), style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 14.sp, color = Ink,
                        ),
                    )
                    Icon(Icons.AutoMirrored.Outlined.ArrowForward, contentDescription = null, tint = Ink, modifier = Modifier.size(16.dp))
                }
            }
        }
    }
}

@Composable
private fun PickerCell(
    initials: String,
    color: Color,
    name: String,
    os: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val mesh = MeshTheme.colors
    val bg = if (selected) mesh.limeFill else mesh.card
    val border = if (selected) Lime else mesh.outline
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .border(if (selected) 1.5.dp else 1.dp, border, RoundedCornerShape(16.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(PaddingValues(vertical = 14.dp, horizontal = 10.dp)),
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            MeshAvatar(initials = initials, color = color, sizeDp = 44)
            Spacer(Modifier.height(8.dp))
            Text(
                name,
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 14.sp, color = mesh.textPrimary,
                ),
            )
            Text(
                os,
                style = TextStyle(
                    fontFamily = GeistMono, fontWeight = FontWeight.W500,
                    fontSize = 9.sp, color = mesh.textTertiary,
                ),
            )
        }
        if (selected) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .size(22.dp)
                    .clip(CircleShape)
                    .background(Lime),
                contentAlignment = Alignment.Center,
            ) {
                Text("✓", style = TextStyle(fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700, fontSize = 13.sp, color = Ink))
            }
        }
    }
}
