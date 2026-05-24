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
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.mock.MockPendingOfferItem
import com.welape.meshdrop.ui.components.AsciiDivider
import com.welape.meshdrop.ui.components.ChipTone
import com.welape.meshdrop.ui.components.FileGlyph
import com.welape.meshdrop.ui.components.MeshAvatar
import com.welape.meshdrop.ui.components.MeshChip
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.theme.AvatarLilac
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FileOfferSheet(onClose: () -> Unit) {
    val mesh = MeshTheme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
        containerColor = mesh.card,
        contentColor = mesh.textPrimary,
    ) {
        FileOfferSheetContent(onClose = onClose)
    }
}

@Composable
fun FileOfferSheetContent(onClose: () -> Unit = {}) {
    val mesh = MeshTheme.colors
    Column(
        modifier = Modifier
            .background(mesh.card)
            .fillMaxWidth()
            .padding(PaddingValues(horizontal = 22.dp, vertical = 24.dp)),
    ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "收到文件 · Incoming",
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 22.sp, color = mesh.textPrimary, letterSpacing = (-0.4).sp,
                    ),
                )
                Spacer(Modifier.weight(1f))
                MeshChip(text = MockPendingOfferItem.receivedAt.uppercase(), tone = ChipTone.LIME, mono = true)
            }
            Text(
                "${MockPendingOfferItem.peer} · ${MockPendingOfferItem.deviceName} 发送了一个文件",
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W400,
                    fontSize = 13.sp, color = mesh.textSecondary,
                ),
            )

            Spacer(Modifier.height(14.dp))

            // 发送者卡 + 文件
            Column(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .border(1.dp, mesh.outline, RoundedCornerShape(14.dp))
                    .background(mesh.surface)
                    .padding(PaddingValues(horizontal = 14.dp, vertical = 14.dp)),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    MeshAvatar(initials = "JW", color = AvatarLilac, sizeDp = 36)
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            MockPendingOfferItem.peer,
                            style = TextStyle(
                                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                                fontSize = 14.sp, color = mesh.textPrimary,
                            ),
                        )
                        Text(
                            MockPendingOfferItem.deviceName,
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                                fontSize = 10.sp, color = mesh.textTertiary,
                            ),
                        )
                    }
                    MeshChip(text = "FP MATCH", tone = ChipTone.LIME, mono = true)
                }
                Spacer(Modifier.height(14.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    FileGlyph(ext = "pages", sizeDp = 44.dp)
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            MockPendingOfferItem.fileName,
                            style = TextStyle(
                                fontFamily = Geist, fontWeight = FontWeight.W700,
                                fontSize = 14.sp, color = mesh.textPrimary,
                            ),
                        )
                        Text(
                            MockPendingOfferItem.fileSize,
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W600,
                                fontSize = 12.sp, color = mesh.textSecondary,
                            ),
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                // 文字便签
                MonoLabel("文字便签 · NOTE")
                Spacer(Modifier.height(4.dp))
                Text(
                    "“${MockPendingOfferItem.note}”",
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W400,
                        fontSize = 13.sp, color = mesh.textPrimary, lineHeight = 18.sp,
                    ),
                )
            }

            AsciiDivider(label = "操作 · ACTIONS")

            // 三按钮：拒绝 / 接收 / 接收并打开
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                ActionBtn(
                    label = "拒绝", subtitle = "DENY",
                    bg = mesh.surface, fg = mesh.danger, border = mesh.outline,
                    modifier = Modifier.weight(1f), onClick = onClose,
                )
                ActionBtn(
                    label = "接收", subtitle = "ACCEPT",
                    bg = mesh.card, fg = mesh.textPrimary, border = mesh.textPrimary,
                    modifier = Modifier.weight(1f), onClick = onClose,
                )
                ActionBtn(
                    label = "保存到相册", subtitle = "TO PHOTOS",
                    bg = Lime, fg = Ink, border = Color.Transparent,
                    modifier = Modifier.weight(1f), onClick = onClose,
                )
            }
            Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun ActionBtn(
    label: String, subtitle: String,
    bg: Color, fg: Color, border: Color,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, border, RoundedCornerShape(14.dp))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(PaddingValues(horizontal = 10.dp, vertical = 14.dp)),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            label,
            style = TextStyle(
                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                fontSize = 13.sp, color = fg,
            ),
        )
        Text(
            subtitle,
            style = TextStyle(
                fontFamily = GeistMono, fontWeight = FontWeight.W700,
                fontSize = 9.sp, color = fg.copy(alpha = 0.65f), letterSpacing = 1.4.sp,
            ),
        )
    }
}
