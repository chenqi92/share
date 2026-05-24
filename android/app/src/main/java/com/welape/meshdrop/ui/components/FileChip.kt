package com.welape.meshdrop.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.LimeDeep
import com.welape.meshdrop.ui.theme.MeshTheme

private fun extColor(ext: String): Color = when (ext.lowercase()) {
    "pdf" -> Color(0xFFD15A3A)
    "zip", "tar", "gz" -> Color(0xFFA68B3F)
    "fig" -> Color(0xFF7B5BD9)
    "heic", "jpg", "png", "webp", "raw" -> Color(0xFF2E8E6E)
    "mp4", "mov", "mkv" -> Color(0xFF3F66C9)
    "md", "txt" -> Color(0xFF555555)
    "sh", "py", "kt", "swift" -> Color(0xFFCA4A6A)
    else -> Color(0xFF666666)
}

/** "纸样" icon：白底卡 + 右上折角 + 中下大写扩展名（彩色）。 */
@Composable
fun FileGlyph(ext: String, sizeDp: Dp = 38.dp) {
    val mesh = MeshTheme.colors
    Box(
        modifier = Modifier
            .size(sizeDp, sizeDp * 1.21f)
            .clip(RoundedCornerShape(6.dp))
            .background(if (mesh.isDark) Color(0xFFF5EFE2) else Color.White)
            .border(1.dp, mesh.outline, RoundedCornerShape(6.dp)),
    ) {
        // 折角阴影
        Canvas(modifier = Modifier.fillMaxSize()) {
            val foldSize = size.width * 0.32f
            val foldPath = Path().apply {
                moveTo(size.width - foldSize, 0f)
                lineTo(size.width, foldSize)
                lineTo(size.width - foldSize, foldSize)
                close()
            }
            drawPath(foldPath, color = Color(0x14000000))
        }
        // 文件名行（淡灰横线）
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(start = 5.dp, end = 5.dp, top = 7.dp),
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            repeat(3) { i ->
                Box(
                    Modifier
                        .height(2.dp)
                        .fillMaxWidth(fraction = listOf(0.72f, 0.55f, 0.40f)[i])
                        .background(Color(0x33000000)),
                )
            }
        }
        // 中下 大写扩展名
        Text(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 5.dp),
            text = ext.uppercase().take(4),
            style = TextStyle(
                fontFamily = GeistMono,
                fontWeight = FontWeight.W700,
                fontSize = 9.sp,
                letterSpacing = 0.4.sp,
                color = extColor(ext),
            ),
        )
    }
}

/** 文件 chip：左侧 glyph + 右侧 name + size（可选 progress 进度条）。 */
@Composable
fun FileChip(
    name: String,
    size: String,
    ext: String,
    progress: Int? = null,
    modifier: Modifier = Modifier,
    onSurface: Color = MeshTheme.colors.textPrimary,
    onSurfaceSecondary: Color = MeshTheme.colors.textSecondary,
) {
    val mesh = MeshTheme.colors
    Column(modifier = modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            FileGlyph(ext = ext, sizeDp = 36.dp)
            Box(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = name,
                    style = TextStyle(
                        fontFamily = com.welape.meshdrop.ui.theme.Geist,
                        fontWeight = FontWeight.W600,
                        fontSize = 13.sp,
                        color = onSurface,
                    ),
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                )
                Box(Modifier.size(2.dp))
                Text(
                    text = size,
                    style = TextStyle(
                        fontFamily = GeistMono,
                        fontWeight = FontWeight.W500,
                        fontSize = 11.sp,
                        color = onSurfaceSecondary,
                    ),
                )
            }
        }
        if (progress != null) {
            Box(
                Modifier
                    .padding(top = 8.dp)
                    .height(4.dp)
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(2.dp))
                    .background(mesh.outline),
            ) {
                Box(
                    Modifier
                        .fillMaxWidth(progress / 100f)
                        .fillMaxSize()
                        .background(LimeDeep),
                )
            }
        }
    }
}
