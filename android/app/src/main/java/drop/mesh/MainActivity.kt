package drop.mesh

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import drop.mesh.ui.ShareApp
import drop.mesh.ui.theme.MeshDropTheme
import drop.mesh.viewmodel.DeviceListViewModel

class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) viewModel.start()
    }

    private lateinit var viewModel: DeviceListViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val vm: DeviceListViewModel = viewModel()
            viewModel = vm
            MeshDropTheme {
                ShareApp(viewModel = vm)
            }
        }
        ensurePermissionThenStart()
    }

    private fun ensurePermissionThenStart() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                this, Manifest.permission.NEARBY_WIFI_DEVICES
            ) == PackageManager.PERMISSION_GRANTED
            if (granted) {
                viewModel.start()
            } else {
                permissionLauncher.launch(Manifest.permission.NEARBY_WIFI_DEVICES)
            }
        } else {
            viewModel.start()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::viewModel.isInitialized) viewModel.stop()
    }
}
