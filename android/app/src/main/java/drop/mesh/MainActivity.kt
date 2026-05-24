package drop.mesh

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.CompositionLocalProvider
import androidx.core.content.ContextCompat
import drop.mesh.ui.LocalEngine
import drop.mesh.ui.ShareApp
import drop.mesh.ui.theme.MeshDropTheme

class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) appEngine().start()
    }

    private fun appEngine() = (application as ShareApplication).engine

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            CompositionLocalProvider(LocalEngine provides appEngine()) {
                MeshDropTheme { ShareApp() }
            }
        }
        ensurePermissionThenStart()
    }

    private fun ensurePermissionThenStart() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
            if (granted) appEngine().start()
            else permissionLauncher.launch(Manifest.permission.NEARBY_WIFI_DEVICES)
        } else {
            appEngine().start()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        appEngine().stop()
    }
}
