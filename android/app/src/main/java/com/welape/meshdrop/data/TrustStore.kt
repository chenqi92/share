package com.welape.meshdrop.data

import android.content.Context

/** 信任记录 — fp、对端名快照、最近一次见到时间。 */
data class TrustRecord(
    val fingerprint: String,
    val name: String,
    val lastSeen: Long,
)

/**
 * 信任的设备指纹库。骨架阶段写到 SharedPreferences；v1.0 切到
 * EncryptedSharedPreferences。
 */
class TrustStore(context: Context) {
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun isTrusted(fingerprint: String): Boolean = prefs.contains(fingerprint)

    fun trust(fingerprint: String, name: String) {
        prefs.edit()
            .putString(fingerprint, "$name|${System.currentTimeMillis()}")
            .apply()
    }

    fun touch(fingerprint: String) {
        val cur = prefs.getString(fingerprint, null) ?: return
        val name = cur.substringBefore("|")
        prefs.edit()
            .putString(fingerprint, "$name|${System.currentTimeMillis()}")
            .apply()
    }

    fun revoke(fingerprint: String) {
        prefs.edit().remove(fingerprint).apply()
    }

    fun snapshot(): List<TrustRecord> = prefs.all.mapNotNull { (fp, value) ->
        val s = value as? String ?: return@mapNotNull null
        val parts = s.split("|", limit = 2)
        TrustRecord(fp, parts[0], parts.getOrNull(1)?.toLongOrNull() ?: 0L)
    }.sortedByDescending { it.lastSeen }

    companion object {
        private const val PREFS = "meshdrop.trust"
    }
}
