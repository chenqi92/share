package com.welape.meshdrop.discovery

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import com.welape.meshdrop.data.Device
import com.welape.meshdrop.data.DeviceOS
import com.welape.meshdrop.data.Identity
import com.welape.meshdrop.data.TXTRecord
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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

    // Wi-Fi 网卡默认丢弃多播帧；不持锁时 DNS-SD 的 onServiceFound / resolve 应答收不到，发现恒为空。
    private var multicastLock: WifiManager.MulticastLock? = null

    // legacy NsdManager.resolveService 同时只能有一个在途，并发会回 FAILURE_ALREADY_ACTIVE；用互斥串行化。
    private val resolveMutex = Mutex()

    // API 34+：用 registerServiceInfoCallback 取代已废弃、在新系统上 onServiceFound 后 resolve 不稳定的 resolveService。
    private val infoCallbacks = ConcurrentHashMap<String, NsdManager.ServiceInfoCallback>()

    fun start(port: Int) {
        acquireMulticastLock()
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
        if (Build.VERSION.SDK_INT >= 34) {
            infoCallbacks.values.forEach { cb ->
                try { nsd.unregisterServiceInfoCallback(cb) } catch (_: Exception) {}
            }
        }
        infoCallbacks.clear()
        scope.cancel()
        deviceMap.clear()
        _devices.value = emptyList()
        releaseMulticastLock()
    }

    private fun acquireMulticastLock() {
        if (multicastLock?.isHeld == true) return
        val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return
        multicastLock = wifi.createMulticastLock("meshdrop-mdns").apply {
            setReferenceCounted(false)
            try { acquire() } catch (e: Exception) { Log.w(TAG, "multicast lock acquire failed", e) }
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.let { lock ->
            if (lock.isHeld) try { lock.release() } catch (_: Exception) {}
        }
        multicastLock = null
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
                Log.i(TAG, "onServiceFound: ${info.serviceName}")
                if (Build.VERSION.SDK_INT >= 34) monitorService(info)
                else scope.launch { resolveAndAdd(info) }
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

    @RequiresApi(34)
    private fun monitorService(info: NsdServiceInfo) {
        val key = info.serviceName
        if (infoCallbacks.containsKey(key)) return
        val cb = object : NsdManager.ServiceInfoCallback {
            override fun onServiceInfoCallbackRegistrationFailed(errorCode: Int) {
                Log.e(TAG, "info cb reg failed for $key: $errorCode")
                infoCallbacks.remove(key)
            }
            override fun onServiceUpdated(updated: NsdServiceInfo) {
                val device = TXTRecord.decode(updated.attributes.mapValues { it.value })
                if (device == null) {
                    Log.w(TAG, "decode null for $key attrs=${updated.attributes.keys}")
                    return
                }
                if (device.id == identity.id) return
                val host = updated.hostAddresses.firstOrNull()?.hostAddress
                deviceMap[device.id] = device.copy(host = host)
                _devices.value = deviceMap.values.sortedBy { it.name }
                Log.i(TAG, "added ${device.id} (${device.name}) host=$host total=${deviceMap.size}")
            }
            override fun onServiceLost() {
                if (deviceMap.remove(key) != null) {
                    _devices.value = deviceMap.values.sortedBy { it.name }
                }
            }
            override fun onServiceInfoCallbackUnregistered() {
                infoCallbacks.remove(key)
            }
        }
        infoCallbacks[key] = cb
        try {
            nsd.registerServiceInfoCallback(info, context.mainExecutor, cb)
        } catch (e: Exception) {
            Log.e(TAG, "registerServiceInfoCallback failed for $key", e)
            infoCallbacks.remove(key)
        }
    }

    private suspend fun resolveAndAdd(info: NsdServiceInfo) {
        val resolved = resolveMutex.withLock { resolve(info) } ?: return
        val attrs = resolved.attributes.mapValues { it.value }
        val device = TXTRecord.decode(attrs) ?: return
        if (device.id == identity.id) return
        val hostAddress = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            resolved.hostAddresses.firstOrNull()?.hostAddress
        } else {
            @Suppress("DEPRECATION")
            resolved.host?.hostAddress
        }
        val withHost = device.copy(host = hostAddress)
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
