package com.welape.meshdrop.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.welape.meshdrop.R

val SpaceGrotesk = FontFamily(Font(R.font.space_grotesk))
val Geist        = FontFamily(Font(R.font.geist))
val GeistMono    = FontFamily(Font(R.font.geist_mono))

// MeshDrop typography：display 用 Space Grotesk，body 用 Geist，mono 字段用 GeistMono。
val MeshTypography = Typography(
    displayLarge = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
        fontSize = 38.sp, letterSpacing = (-0.6).sp, lineHeight = 42.sp,
    ),
    displayMedium = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
        fontSize = 30.sp, letterSpacing = (-0.4).sp, lineHeight = 34.sp,
    ),
    displaySmall = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
        fontSize = 22.sp, letterSpacing = (-0.3).sp, lineHeight = 26.sp,
    ),
    headlineLarge = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
        fontSize = 26.sp, letterSpacing = (-0.4).sp, lineHeight = 30.sp,
    ),
    headlineMedium = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
        fontSize = 18.sp, letterSpacing = (-0.2).sp, lineHeight = 22.sp,
    ),
    headlineSmall = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W600,
        fontSize = 15.sp, lineHeight = 19.sp,
    ),
    titleLarge = TextStyle(
        fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
        fontSize = 16.sp, lineHeight = 20.sp,
    ),
    titleMedium = TextStyle(
        fontFamily = Geist, fontWeight = FontWeight.W600,
        fontSize = 14.sp, lineHeight = 18.sp,
    ),
    titleSmall = TextStyle(
        fontFamily = Geist, fontWeight = FontWeight.W600,
        fontSize = 13.sp, lineHeight = 17.sp,
    ),
    bodyLarge = TextStyle(
        fontFamily = Geist, fontWeight = FontWeight.W400,
        fontSize = 14.sp, lineHeight = 20.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = Geist, fontWeight = FontWeight.W400,
        fontSize = 13.sp, lineHeight = 18.sp,
    ),
    bodySmall = TextStyle(
        fontFamily = Geist, fontWeight = FontWeight.W400,
        fontSize = 12.sp, lineHeight = 16.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = Geist, fontWeight = FontWeight.W600,
        fontSize = 13.sp, lineHeight = 16.sp,
    ),
    labelMedium = TextStyle(
        fontFamily = Geist, fontWeight = FontWeight.W600,
        fontSize = 11.sp, letterSpacing = 0.3.sp, lineHeight = 14.sp,
    ),
    labelSmall = TextStyle(
        fontFamily = GeistMono, fontWeight = FontWeight.W500,
        fontSize = 10.sp, letterSpacing = 0.5.sp, lineHeight = 13.sp,
    ),
)

// ASCII / 大写 tag / 时间戳常用 helper
val MonoCaption = TextStyle(
    fontFamily = GeistMono, fontWeight = FontWeight.W500,
    fontSize = 11.sp, letterSpacing = 0.5.sp, lineHeight = 14.sp,
)

val MonoTag = TextStyle(
    fontFamily = GeistMono, fontWeight = FontWeight.W700,
    fontSize = 10.sp, letterSpacing = 1.6.sp, lineHeight = 12.sp,
)

val MonoNumber = TextStyle(
    fontFamily = GeistMono, fontWeight = FontWeight.W500,
    fontSize = 11.sp, lineHeight = 14.sp,
)
