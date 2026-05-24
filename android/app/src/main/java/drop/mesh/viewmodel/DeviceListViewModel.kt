package drop.mesh.viewmodel

import android.app.Application
import android.os.Build
import androidx.lifecycle.AndroidViewModel
import drop.mesh.ShareApplication
import drop.mesh.data.Device
import drop.mesh.data.Identity
import drop.mesh.discovery.MdnsDiscovery
import kotlinx.coroutines.flow.StateFlow

class DeviceListViewModel(app: Application) : AndroidViewModel(app) {
    private val identity: Identity = (app as ShareApplication).identity
    val displayName: String = Build.MODEL ?: "Android"
    val fingerprint: String get() = identity.fingerprint

    private val discovery = MdnsDiscovery(
        context = app,
        identity = identity,
        displayName = displayName,
        model = "${Build.MANUFACTURER} ${Build.MODEL}",
    )

    val devices: StateFlow<List<Device>> = discovery.devices

    fun start() = discovery.start()
    fun stop() = discovery.stop()
}
