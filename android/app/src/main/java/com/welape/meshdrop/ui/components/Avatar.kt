package com.welape.meshdrop.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

@Composable
fun MeshAvatar(
    initials: String,
    color: Color,
    sizeDp: Int = 32,
    ringColor: Color? = null,
) {
    val ringPx = if (ringColor != null) 2 else 0
    val outer = sizeDp + ringPx * 2
    Box(
        modifier = Modifier.size(outer.dp),
        contentAlignment = Alignment.Center,
    ) {
        if (ringColor != null) {
            Box(
                Modifier
                    .size(outer.dp)
                    .clip(CircleShape)
                    .border(2.dp, ringColor, CircleShape),
            )
        }
        Box(
            Modifier
                .size(sizeDp.dp)
                .clip(CircleShape)
                .background(color),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = initials.take(2).uppercase(),
                style = TextStyle(
                    fontFamily = SpaceGrotesk,
                    fontWeight = FontWeight.W700,
                    fontSize = (sizeDp * 0.4f).sp,
                    color = Ink,
                ),
            )
        }
    }
}

/** 32 大小的 avatar 右下角小绿点（在线） */
@Composable
fun OnlineDot(sizeDp: Int = 9) {
    Box(
        Modifier
            .size(sizeDp.dp)
            .clip(CircleShape)
            .background(Lime)
            .border(1.5.dp, MeshTheme.colors.card, CircleShape),
    )
}
