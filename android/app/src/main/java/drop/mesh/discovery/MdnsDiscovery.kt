package drop.mesh.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import drop.mesh.data.Device
import drop.mesh.data.DeviceOS
import drop.mesh.data.Identity
import drop.mesh.data.TXTRecord
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.resume

private const val TAG = "MdnsDiscovery"

/**
 * 只管 mDNS 注册 + browse；TCP listener 由 ShareEngine 持有，端口由外部传入。
 */
class MdnsDiscovery(
    private val context: Context,
    private val identity: Identity,
    private val displayName: String,
    private val model: String?,
) {
    private val nsd: NsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _devices = MutableStateFlow<List<Device>>(emptyList())
    val devices: StateFlow<List<Device>> = _devices.asStateFlow()

    private val deviceMap = ConcurrentHashMap<String, Device>()

    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null

    fun start(port: Int) {
        registerService(port)
        startBrowse()
    }

    fun stop() {
        registrationListener?.let {
            try { nsd.unregisterService(it) } catch (_: Exception) {}
        }
        discoveryListener?.let {
            try { nsd.stopServiceDiscovery(it) } catch (_: Exception) {}
        }
        registrationListener = null
        discoveryListener = null
        scope.cancel()
        deviceMap.clear()
        _devices.value = emptyList()
    }

    private fun registerService(port: Int) {
        val info = NsdServiceInfo().apply {
            serviceName = identity.id
            serviceType = TXTRecord.SERVICE_TYPE
            this.port = port
        }
        TXTRecord.encode(
            identity = identity,
            displayName = displayName,
            os = DeviceOS.current,
            model = model,
            port = port,
        ).forEach { (k, v) -> info.setAttribute(k, v.toString(Charsets.UTF_8)) }

        val listener = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(s: NsdServiceInfo) {
                Log.i(TAG, "registered: ${s.serviceName}")
            }
            override fun onRegistrationFailed(s: NsdServiceInfo, code: Int) {
                Log.e(TAG, "registration failed: $code")
            }
            override fun onServiceUnregistered(s: NsdServiceInfo) {}
            override fun onUnregistrationFailed(s: NsdServiceInfo, code: Int) {}
        }
        registrationListener = listener
        nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    private fun startBrowse() {
        val listener = object : NsdManager.DiscoveryListener {
            override fun onStartDiscoveryFailed(serviceType: String, code: Int) {
                Log.e(TAG, "start discovery failed: $code")
            }
            override fun onStopDiscoveryFailed(serviceType: String, code: Int) {}
            override fun onDiscoveryStarted(serviceType: String) {
                Log.i(TAG, "discovery started")
            }
            override fun onDiscoveryStopped(serviceType: String) {}

            override fun onServiceFound(info: NsdServiceInfo) {
                if (info.serviceName == identity.id) return
                scope.launch { resolveAndAdd(info) }
            }

            override fun onServiceLost(info: NsdServiceInfo) {
                if (deviceMap.remove(info.serviceName) != null) {
                    _devices.value = deviceMap.values.sortedBy { it.name }
                }
            }
        }
        discoveryListener = listener
        nsd.discoverServices(TXTRecord.SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, listener)
    }

    private suspend fun resolveAndAdd(info: NsdServiceInfo) {
        val resolved = resolve(info) ?: return
        val attrs = resolved.attributes.mapValues { it.value }
        val device = TXTRecord.decode(attrs) ?: return
        if (device.id == identity.id) return
        val withHost = device.copy(host = resolved.host?.hostAddress)
        deviceMap[device.id] = withHost
        _devices.value = deviceMap.values.sortedBy { it.name }
    }

    @Suppress("DEPRECATION")
    private suspend fun resolve(info: NsdServiceInfo): NsdServiceInfo? =
        suspendCancellableCoroutine { cont ->
            val listener = object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                    if (cont.isActive) cont.resume(null)
                }
                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    if (cont.isActive) cont.resume(serviceInfo)
                }
            }
            nsd.resolveService(info, listener)
        }
}
