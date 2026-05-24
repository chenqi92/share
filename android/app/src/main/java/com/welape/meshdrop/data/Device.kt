package com.welape.meshdrop.data

enum class DeviceOS(val raw: String) {
    IOS("ios"),
    ANDROID("android"),
    MACOS("macos"),
    WINDOWS("windows"),
    LINUX("linux");

    companion object {
        fun parse(s: String): DeviceOS? = entries.firstOrNull { it.raw == s }
        val current = ANDROID
    }
}

data class Device(
    val id: String,             // 32 hex
    val name: String,           // 已 base64url 解码
    val os: DeviceOS,
    val model: String?,
    val fingerprint: String,    // 32 hex
    val port: Int,
    val protocolVersion: Int = 1,
    val host: String? = null,   // mDNS 解析得到的 IP / hostname（连接时用）
) {
    /** 把 32 hex 指纹切成 8 组 4 位大写，空格分隔。 */
    val humanFingerprint: String
        get() = fingerprint.uppercase().chunked(4).joinToString(" ")
}
