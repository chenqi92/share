package com.welape.meshdrop.wear.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.wear.compose.material3.Text
import com.welape.meshdrop.wear.ui.theme.MDColor
import com.welape.meshdrop.wear.ui.theme.MDType

@Composable
fun Avatar(
    initials: String,
    color: Color,
    sizeDp: Int,
    ring: Boolean = false,
    ringColor: Color = MDColor.lime,
    modifier: Modifier = Modifier,
) {
    val outerSize = if (ring) sizeDp + 8 else sizeDp
    Box(
        modifier = modifier.size(outerSize.dp),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .size(sizeDp.dp)
                .background(color, CircleShape)
                .then(if (ring) Modifier.border(2.dp, ringColor, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = initials,
                color = MDColor.dink,
                style = MDType.display(sizeDp * 0.40f, FontWeight.Bold),
            )
        }
    }
}
