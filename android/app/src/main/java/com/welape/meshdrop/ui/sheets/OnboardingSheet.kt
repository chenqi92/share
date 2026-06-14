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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import com.welape.meshdrop.ui.components.MeshDropLockup
import com.welape.meshdrop.ui.components.MonoLabel
import com.welape.meshdrop.ui.theme.Geist
import com.welape.meshdrop.ui.theme.GeistMono
import com.welape.meshdrop.ui.theme.Ink
import com.welape.meshdrop.ui.theme.Lime
import com.welape.meshdrop.ui.theme.MeshTheme
import com.welape.meshdrop.ui.theme.SpaceGrotesk

data class OnboardStep(val tag: String, val title: String, val body: String)

/** 步骤文案随 locale 切换，故在 @Composable 内用 stringResource 构造，而非 top-level 常量。 */
@Composable
private fun rememberOnboardSteps(): List<OnboardStep> = listOf(
    OnboardStep(
        stringResource(R.string.onboarding_step1_tag),
        stringResource(R.string.onboarding_step1_title),
        stringResource(R.string.onboarding_step1_body),
    ),
    OnboardStep(
        stringResource(R.string.onboarding_step2_tag),
        stringResource(R.string.onboarding_step2_title),
        stringResource(R.string.onboarding_step2_body),
    ),
    OnboardStep(
        stringResource(R.string.onboarding_step3_tag),
        stringResource(R.string.onboarding_step3_title),
        stringResource(R.string.onboarding_step3_body),
    ),
    OnboardStep(
        stringResource(R.string.onboarding_step4_tag),
        stringResource(R.string.onboarding_step4_title),
        stringResource(R.string.onboarding_step4_body),
    ),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OnboardingSheet(onClose: () -> Unit) {
    val mesh = MeshTheme.colors
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onClose,
        sheetState = sheetState,
        containerColor = mesh.card,
        contentColor = mesh.textPrimary,
    ) {
        OnboardingSheetContent(onClose = onClose)
    }
}

@Composable
fun OnboardingSheetContent(onClose: () -> Unit = {}) {
    val mesh = MeshTheme.colors
    val steps = rememberOnboardSteps()
    var idx by remember { mutableStateOf(0) }
    val step = steps[idx]
    Column(
        modifier = Modifier
            .background(mesh.card)
            .fillMaxWidth()
            .padding(PaddingValues(horizontal = 22.dp, vertical = 24.dp)),
    ) {
            MeshDropLockup(markSize = 26.dp, fontSize = 20.sp)
            Spacer(Modifier.height(18.dp))

            MonoLabel(step.tag)
            Spacer(Modifier.height(8.dp))
            Text(
                step.title,
                style = TextStyle(
                    fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                    fontSize = 30.sp, color = mesh.textPrimary, letterSpacing = (-0.6).sp,
                ),
            )
            Spacer(Modifier.height(8.dp))
            Text(
                step.body,
                style = TextStyle(
                    fontFamily = Geist, fontWeight = FontWeight.W400,
                    fontSize = 14.sp, color = mesh.textSecondary, lineHeight = 22.sp,
                ),
            )

            Spacer(Modifier.height(18.dp))

            // 进度点
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                steps.forEachIndexed { i, _ ->
                    val active = i == idx
                    Box(
                        Modifier
                            .height(6.dp)
                            .let { if (active) it.size(width = 26.dp, height = 6.dp) else it.size(width = 8.dp, height = 6.dp) }
                            .clip(RoundedCornerShape(3.dp))
                            .background(if (active) Lime else mesh.outline),
                    )
                }
            }

            Spacer(Modifier.height(18.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
                Box(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .border(1.dp, mesh.outline, RoundedCornerShape(14.dp))
                        .background(Color.Transparent)
                        .clickable {
                            if (idx > 0) idx-- else onClose()
                        }
                        .padding(PaddingValues(vertical = 14.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (idx == 0) stringResource(R.string.onboarding_skip) else stringResource(R.string.onboarding_prev),
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 14.sp, color = mesh.textPrimary,
                        ),
                    )
                }
                Box(
                    Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(Lime)
                        .clickable {
                            if (idx < steps.lastIndex) idx++ else onClose()
                        }
                        .padding(PaddingValues(vertical = 14.dp)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        if (idx == steps.lastIndex) stringResource(R.string.onboarding_start) else stringResource(R.string.onboarding_next),
                        style = TextStyle(
                            fontFamily = SpaceGrotesk, fontWeight = FontWeight.W700,
                            fontSize = 14.sp, color = Ink,
                        ),
                    )
                }
            }
            Spacer(Modifier.height(24.dp))
    }
}
