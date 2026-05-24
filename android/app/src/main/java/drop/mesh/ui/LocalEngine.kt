package drop.mesh.ui

import androidx.compose.runtime.staticCompositionLocalOf
import drop.mesh.transport.ShareEngine

val LocalEngine = staticCompositionLocalOf<ShareEngine> {
    error("ShareEngine not provided in CompositionLocal")
}
