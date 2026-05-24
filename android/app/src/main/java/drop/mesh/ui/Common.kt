package drop.mesh.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material.icons.filled.DesktopWindows
import androidx.compose.material.icons.filled.Laptop
import androidx.compose.material.icons.filled.PhoneAndroid
import androidx.compose.material.icons.filled.PhoneIphone
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import drop.mesh.data.DeviceOS

object OsStyle {
    fun gradient(os: DeviceOS): Brush = when (os) {
        DeviceOS.IOS     -> Brush.linearGradient(listOf(Color(0xFF3B82F6), Color(0xFF6366F1)))
        DeviceOS.ANDROID -> Brush.linearGradient(listOf(Color(0xFF22C55E), Color(0xFF14B8A6)))
        DeviceOS.MACOS   -> Brush.linearGradient(listOf(Color(0xFFA855F7), Color(0xFFEC4899)))
        DeviceOS.WINDOWS -> Brush.linearGradient(listOf(Color(0xFF06B6D4), Color(0xFF3B82F6)))
        DeviceOS.LINUX   -> Brush.linearGradient(listOf(Color(0xFFFB923C), Color(0xFFEF4444)))
    }

    fun icon(os: DeviceOS): ImageVector = when (os) {
        DeviceOS.IOS     -> Icons.Filled.PhoneIphone
        DeviceOS.ANDROID -> Icons.Filled.PhoneAndroid
        DeviceOS.MACOS   -> Icons.Filled.Laptop
        DeviceOS.WINDOWS -> Icons.Filled.DesktopWindows
        DeviceOS.LINUX   -> Icons.Filled.Computer
    }

    fun displayName(os: DeviceOS): String = when (os) {
        DeviceOS.IOS     -> "iOS"
        DeviceOS.ANDROID -> "Android"
        DeviceOS.MACOS   -> "macOS"
        DeviceOS.WINDOWS -> "Windows"
        DeviceOS.LINUX   -> "Linux"
    }
}

@Composable
fun OsBadge(os: DeviceOS, size: Int) {
    androidx.compose.foundation.layout.Box(
        modifier = Modifier
            .size(size.dp)
            .clip(RoundedCornerShape((size * 0.28).dp))
            .background(OsStyle.gradient(os)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = OsStyle.icon(os),
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size((size * 0.5).dp),
        )
    }
}
