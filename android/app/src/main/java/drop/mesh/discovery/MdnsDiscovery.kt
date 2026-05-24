package drop.mesh.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.util.Log
import drop.mesh.data.Device
import drop.mesh.data.DeviceOS
import drop.mesh.data.Identity
import drop.mesh.data.TXTRecord
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import java.net.ServerSocket
import java.util.concurrent.ConcurrentHashMap
import kotlin.coroutines.resume

private const val TAG = "MdnsDiscovery"

/**
 * 同网段设备发现。同时承担 responder（广告本机）与 querier（浏览其他端）。
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

    private var serverSocket: ServerSocket? = null
    private var registrationListener: NsdManager.RegistrationListener? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null

    fun start() {
        scope.launch {
            // 分配端口
            val sock = ServerSocket(0)
            serverSocket = sock
            val port = sock.localPort
            Log.i(TAG, "listening on port $port (skeleton: connections accepted but closed)")

            // 骨架阶段不处理业务连接，accept 后直接关。
            scope.launch {
                while (!sock.isClosed) {
                    try {
                        val client = sock.accept()
                        Log.d(TAG, "incoming connection from ${client.inetAddress}; closing (skeleton)")
                        client.close()
                    } catch (_: Exception) {
                        break
                    }
                }
            }

            registerService(port)
            startDiscovery()
        }
    }

    fun stop() {
        registrationListener?.let { nsd.unregisterService(it) }
        discoveryListener?.let { nsd.stopServiceDiscovery(it) }
        registrationListener = null
        discoveryListener = null
        serverSocket?.close()
        serverSocket = null
    }

    private fun registerService(port: Int) {
        val info = NsdServiceInfo().apply {
            serviceName = identity.id     // 实例名用 device id
            serviceType = TXTRecord.SERVICE_TYPE
            this.port = port
        }
        // setAttribute 是 API 21+
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

    private fun startDiscovery() {
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
                if (info.serviceName == identity.id) return  // 过滤自己
                scope.launch { resolveAndAdd(info) }
            }

            override fun onServiceLost(info: NsdServiceInfo) {
                deviceMap.remove(info.serviceName)
                _devices.value = deviceMap.values.sortedBy { it.name }
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
        deviceMap[device.id] = device
        _devices.value = deviceMap.values.sortedBy { it.name }
    }

    /** [NsdManager.resolveService] 的协程封装。Android 14+ 标记为 deprecated，
     *  推荐用 [NsdManager.registerServiceInfoCallback]；这里先用兼容旧版的方式。 */
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
