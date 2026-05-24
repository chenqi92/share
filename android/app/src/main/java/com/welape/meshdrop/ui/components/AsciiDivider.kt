package com.welape.meshdrop.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.MeshTheme

/** 左右两条 hr + 中间 mono 全大写 label。极客感分隔。 */
@Composable
fun AsciiDivider(
    label: String,
    modifier: Modifier = Modifier,
) {
    val mesh = MeshTheme.colors
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(PaddingValues(vertical = 14.dp)),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        HorizontalDivider(
            modifier = Modifier.weight(1f),
            thickness = 1.dp,
            color = mesh.divider,
        )
        Text(
            text = "── ${label.uppercase()} ──",
            style = TextStyle(
                fontFamily = GeistMono,
                fontWeight = FontWeight.W700,
                fontSize = 10.sp,
                letterSpacing = 1.8.sp,
                color = mesh.textTertiary,
            ),
        )
        HorizontalDivider(
            modifier = Modifier.weight(1f),
            thickness = 1.dp,
            color = mesh.divider,
        )
    }
}

/** 单 label，没有左右 hr 包夹。 */
@Composable
fun MonoLabel(
    label: String,
    modifier: Modifier = Modifier,
) {
    Text(
        modifier = modifier,
        text = label.uppercase(),
        style = TextStyle(
            fontFamily = GeistMono,
            fontWeight = FontWeight.W700,
            fontSize = 10.sp,
            letterSpacing = 1.8.sp,
            color = MeshTheme.colors.textTertiary,
        ),
    )
}
