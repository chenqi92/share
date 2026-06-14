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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.R
import com.welape.meshdrop.data.PendingFileOffer
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
import kotlin.math.max

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FileOfferSheet(
    offer: PendingFileOffer? = null,
    useMockFallback: Boolean = true,
    onRespond: (Boolean) -> Unit = {},
    onClose: () -> Unit,
) {
    val mesh = MeshTheme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
        containerColor = mesh.card,
        contentColor = mesh.textPrimary,
    ) {
        FileOfferSheetContent(
            offer = offer,
            useMockFallback = useMockFallback,
            onRespond = onRespond,
            onClose = onClose,
        )
    }
}

@Composable
fun FileOfferSheetContent(
    offer: PendingFileOffer? = null,
    useMockFallback: Boolean = true,
    onRespond: (Boolean) -> Unit = {},
    onClose: () -> Unit = {},
) {
    val mesh = MeshTheme.colors
    val model = offer?.toFileOfferSheetModel()
        ?: if (useMockFallback) MockPendingOfferItem.toFileOfferSheetModel() else null
    Column(
        modifier = Modifier
            .background(mesh.card)
            .fillMaxWidth()
            .padding(PaddingValues(horizontal = 22.dp, vertical = 24.dp)),
    ) {
        if (model == null) {
            EmptyOffer(stringResource(R.string.offer_empty), onClose)
            return@Column
        }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    stringResource(R.string.offer_title),
                    style = TextStyle(
                        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                        fontSize = 22.sp, color = mesh.textPrimary, letterSpacing = (-0.4).sp,
                    ),
                )
                Spacer(Modifier.weight(1f))
                MeshChip(text = model.receivedAt.uppercase(), tone = ChipTone.LIME, mono = true)
            }
            Text(
                stringResource(R.string.offer_sent_a_file, model.peer, model.deviceName),
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
                    MeshAvatar(initials = model.initials, color = AvatarLilac, sizeDp = 36)
                    Spacer(Modifier.width(10.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            model.peer,
                            style = TextStyle(
                                fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                                fontSize = 14.sp, color = mesh.textPrimary,
                            ),
                        )
                        Text(
                            model.deviceName,
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W500,
                                fontSize = 10.sp, color = mesh.textTertiary,
                            ),
                        )
                    }
                    MeshChip(text = stringResource(R.string.offer_fp_match), tone = ChipTone.LIME, mono = true)
                }
                Spacer(Modifier.height(14.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    FileGlyph(ext = model.fileExt, sizeDp = 44.dp)
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            model.fileName,
                            style = TextStyle(
                                fontFamily = Geist, fontWeight = FontWeight.W700,
                                fontSize = 14.sp, color = mesh.textPrimary,
                            ),
                        )
                        Text(
                            model.fileSize,
                            style = TextStyle(
                                fontFamily = GeistMono, fontWeight = FontWeight.W600,
                                fontSize = 12.sp, color = mesh.textSecondary,
                            ),
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                // 文字便签
                MonoLabel(stringResource(R.string.offer_note_label))
                Spacer(Modifier.height(4.dp))
                Text(
                    "“${model.note}”",
                    style = TextStyle(
                        fontFamily = Geist, fontWeight = FontWeight.W400,
                        fontSize = 13.sp, color = mesh.textPrimary, lineHeight = 18.sp,
                    ),
                )
            }

            AsciiDivider(label = stringResource(R.string.offer_section_actions))

            // 三按钮：拒绝 / 接收 / 接收并打开
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                ActionBtn(
                    label = stringResource(R.string.offer_deny), subtitle = stringResource(R.string.offer_deny_sub),
                    bg = mesh.surface, fg = mesh.danger, border = mesh.outline,
                    modifier = Modifier.weight(1f), onClick = {
                        onRespond(false)
                        onClose()
                    },
                )
                ActionBtn(
                    label = stringResource(R.string.offer_accept), subtitle = stringResource(R.string.offer_accept_sub),
                    bg = mesh.card, fg = mesh.textPrimary, border = mesh.textPrimary,
                    modifier = Modifier.weight(1f), onClick = {
                        onRespond(true)
                        onClose()
                    },
                )
                ActionBtn(
                    label = stringResource(R.string.offer_to_photos), subtitle = stringResource(R.string.offer_to_photos_sub),
                    bg = Lime, fg = Ink, border = Color.Transparent,
                    modifier = Modifier.weight(1f), onClick = {
                        onRespond(true)
                        onClose()
                    },
                )
            }
            Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun EmptyOffer(message: String, onClose: () -> Unit) {
    val mesh = MeshTheme.colors
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Text(
            message,
            style = TextStyle(
                fontFamily = Geist, fontWeight = FontWeight.W600,
                fontSize = 14.sp, color = mesh.textPrimary,
            ),
        )
        ActionBtn(
            label = stringResource(R.string.offer_close), subtitle = stringResource(R.string.offer_close_sub),
            bg = mesh.surface, fg = mesh.textPrimary, border = mesh.outline,
            onClick = onClose,
        )
    }
}

private data class FileOfferSheetModel(
    val peer: String,
    val deviceName: String,
    val fileName: String,
    val fileSize: String,
    val fileExt: String,
    val note: String,
    val initials: String,
    val receivedAt: String,
)

private fun PendingFileOffer.toFileOfferSheetModel(): FileOfferSheetModel {
    val peerName = peer.name.ifBlank { peer.id.take(8) }
    return FileOfferSheetModel(
        peer = peerName,
        deviceName = peer.model ?: peer.os.raw,
        fileName = fileName,
        fileSize = formattedSize,
        fileExt = fileName.substringAfterLast('.', "bin").lowercase(),
        note = "SHA-256 ${sha256.take(16).uppercase()}",
        initials = peerName.take(2).uppercase(),
        receivedAt = relativeAge(receivedAt),
    )
}

private fun com.welape.meshdrop.mock.MockPendingOffer.toFileOfferSheetModel(): FileOfferSheetModel =
    FileOfferSheetModel(
        peer = peer,
        deviceName = deviceName,
        fileName = fileName,
        fileSize = fileSize,
        fileExt = fileName.substringAfterLast('.', "bin").lowercase(),
        note = note,
        initials = peer.take(2).uppercase(),
        receivedAt = receivedAt,
    )

private fun relativeAge(ts: Long): String {
    val seconds = max(0L, (System.currentTimeMillis() - ts) / 1000)
    return when {
        seconds < 60 -> "${seconds}s ago"
        seconds < 3600 -> "${seconds / 60}m ago"
        else -> "${seconds / 3600}h ago"
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
