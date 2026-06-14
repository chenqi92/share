package com.welape.meshdrop.data

import android.util.Base64

/**
 * mDNS TXT 记录的编解码。字段见 [discovery.md](../../../../../../../protocol/discovery.md)。
 */
object TXTRecord {
    // NsdManager 注册/浏览要求无尾点的 "_meshdrop._tcp"，域名 .local. 由系统自动补。
    // 与 Apple/Windows/Linux 各端统一，避免跨端浏览匹配失败。
    const val SERVICE_TYPE = "_meshdrop._tcp"

    fun encode(
        identity: Identity,
        displayName: String,
        os: DeviceOS,
        model: String?,
        port: Int,
        protocolVersion: Int = 1,
    ): Map<String, ByteArray> {
        val out = mutableMapOf<String, ByteArray>()
        out["v"] = protocolVersion.toString().toByteArray(Charsets.US_ASCII)
        out["id"] = identity.id.toByteArray(Charsets.US_ASCII)
        out["name"] = base64UrlEncode(displayName.toByteArray(Charsets.UTF_8)).toByteArray(Charsets.US_ASCII)
        out["os"] = os.raw.toByteArray(Charsets.US_ASCII)
        if (model != null) out["model"] = model.toByteArray(Charsets.UTF_8)
        out["fp"] = identity.fingerprint.toByteArray(Charsets.US_ASCII)
        out["port"] = port.toString().toByteArray(Charsets.US_ASCII)
        return out
    }

    fun decode(attrs: Map<String, ByteArray>): Device? {
        fun s(k: String) = attrs[k]?.toString(Charsets.UTF_8)
        val v = s("v")?.toIntOrNull() ?: return null
        val id = s("id")?.takeIf { it.length == 32 } ?: return null
        val nameB64 = s("name") ?: return null
        val nameBytes = base64UrlDecode(nameB64) ?: return null
        val name = nameBytes.toString(Charsets.UTF_8)
        val osStr = s("os") ?: return null
        val os = DeviceOS.parse(osStr) ?: return null
        val fp = s("fp")?.takeIf { it.length == 32 } ?: return null
        // 端口必须在合法范围；越界（如恶意广播 99999 / -1）直接丢弃该设备，
        // 避免后续 InetSocketAddress(host, port) 在主线程抛 IllegalArgumentException 崩溃。
        val port = s("port")?.toIntOrNull()?.takeIf { it in 1..65535 } ?: return null
        return Device(
            id = id,
            name = name,
            os = os,
            model = s("model"),
            fingerprint = fp,
            port = port,
            protocolVersion = v,
        )
    }

    private fun base64UrlEncode(data: ByteArray): String =
        Base64.encodeToString(data, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)

    private fun base64UrlDecode(s: String): ByteArray? = try {
        Base64.decode(s, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    } catch (_: IllegalArgumentException) {
        null
    }
}
