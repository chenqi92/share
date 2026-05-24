package com.welape.meshdrop.wear.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType

@Composable
fun FileChipMini(
    name: String,
    size: String,
    ext: String,
    modifier: Modifier = Modifier,
) {
    val extColor = when (ext.lowercase()) {
        "pdf", "mp4", "mov" -> MDColor.flame
        "fig" -> Color(0xFFC684FF)
        "zip", "7z" -> MDColor.sky
        "pages", "doc", "docx", "md" -> MDColor.lime
        "heic", "png", "jpg" -> MDColor.sky
        else -> MDColor.muted
    }
    Row(
        modifier = modifier
            .background(MDColor.dink2, RoundedCornerShape(10.dp))
            .border(0.5.dp, MDColor.dline, RoundedCornerShape(10.dp))
            .padding(8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // 纸样 icon
        Box(
            modifier = Modifier
                .size(width = 26.dp, height = 32.dp)
                .background(MDColor.dpaper, RoundedCornerShape(3.dp)),
            contentAlignment = Alignment.BottomCenter,
        ) {
            Text(
                text = ext.uppercase(),
                color = extColor,
                style = MDType.mono(7f, FontWeight.Bold),
                modifier = Modifier.padding(bottom = 4.dp),
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = name,
                color = MDColor.dpaper,
                style = MDType.body(12f, FontWeight.Medium),
                maxLines = 1,
                overflow = TextOverflow.MiddleEllipsis,
            )
            Text(
                text = size,
                color = MDColor.muted,
                style = MDType.mono(10f),
            )
        }
    }
}

@Composable
fun MonoTag(text: String, tone: Tone = Tone.Mute) {
    val (bg, fg) = when (tone) {
        Tone.Mute -> MDColor.dline to MDColor.muted
        Tone.Lime -> MDColor.lime to MDColor.dink
        Tone.Ink -> MDColor.dink3 to MDColor.dpaper
        Tone.Flame -> MDColor.flame to Color.White
        Tone.Sky -> MDColor.sky to Color.White
    }
    Box(
        modifier = Modifier
            .background(bg, RoundedCornerShape(999.dp))
            .padding(horizontal = 6.dp, vertical = 2.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text.uppercase(),
            color = fg,
            style = MDType.mono(10f, FontWeight.Bold, tracking = 1.6f),
        )
    }
}

enum class Tone { Mute, Lime, Ink, Flame, Sky }
