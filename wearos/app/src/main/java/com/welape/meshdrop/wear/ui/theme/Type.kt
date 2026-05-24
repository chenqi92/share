package com.welape.meshdrop.wear.ui.theme

import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

object MDType {
    fun display(size: Float, weight: FontWeight = FontWeight.Bold): TextStyle = TextStyle(
        fontSize = size.sp,
        fontWeight = weight,
        fontFamily = FontFamily.SansSerif,
        letterSpacing = (-0.4).sp,
    )

    fun body(size: Float, weight: FontWeight = FontWeight.Normal): TextStyle = TextStyle(
        fontSize = size.sp,
        fontWeight = weight,
        fontFamily = FontFamily.SansSerif,
    )

    fun mono(size: Float, weight: FontWeight = FontWeight.Normal, tracking: Float = 1.4f): TextStyle = TextStyle(
        fontSize = size.sp,
        fontWeight = weight,
        fontFamily = FontFamily.Monospace,
        letterSpacing = tracking.sp,
    )
}
