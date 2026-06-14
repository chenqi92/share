package com.welape.meshdrop.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.PublicKey
import java.security.SecureRandom
import java.security.spec.PKCS8EncodedKeySpec
import java.security.spec.X509EncodedKeySpec
import java.util.UUID

/**
 * 设备身份。Ed25519 长期密钥 + UUID。
 *
 * 私钥落盘走 EncryptedSharedPreferences：主密钥由 AndroidKeyStore（AES256-GCM）派生，
 * 条目以 AES256-SIV(key)/AES256-GCM(value) 加密，见
 * [security.md](../../../../../../../protocol/security.md)。
 */
data class Identity(
    val id: String,
    val keyPair: KeyPair,
    val fingerprint: String,
)

object IdentityStore {
    // 加密库（新）；明文库（旧）仅用于一次性迁移后清空。
    private const val PREFS = "meshdrop.identity.secure"
    private const val LEGACY_PREFS = "meshdrop.identity"
    private const val KEY_ID = "id"
    private const val KEY_PRIVATE = "private"
    private const val KEY_PUBLIC = "public"

    /**
     * EncryptedSharedPreferences。主密钥放在 AndroidKeyStore，进程外无法读取明文私钥。
     * 初始化失败（极少数 KeyStore 异常机型）兜底回普通 prefs，保证身份仍可用。
     */
    private fun securePrefs(context: Context): SharedPreferences = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            PREFS,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (_: Exception) {
        // KeyStore 异常机型兜底：用独立文件名，避免与加密库 PREFS 在同名文件下混写明/密文。
        context.getSharedPreferences("$PREFS.fallback", Context.MODE_PRIVATE)
    }

    fun loadOrCreate(context: Context): Identity {
        val prefs = securePrefs(context)
        migrateLegacyPlaintext(context, prefs)
        val id = prefs.getString(KEY_ID, null)
        val privB64 = prefs.getString(KEY_PRIVATE, null)
        val pubB64 = prefs.getString(KEY_PUBLIC, null)
        if (id != null && privB64 != null && pubB64 != null) {
            val priv = decodePrivate(Base64.decode(privB64, Base64.NO_WRAP))
            val pub = decodePublic(Base64.decode(pubB64, Base64.NO_WRAP))
            return Identity(id, KeyPair(pub, priv), computeFingerprint(pub))
        }
        return create(prefs)
    }

    fun reset(context: Context) {
        securePrefs(context).edit().clear().apply()
        // 旧明文库若残留也一并清掉。
        context.getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    /** 把历史版本写在明文 SharedPreferences 里的私钥搬进加密库，搬完即清空明文库。 */
    private fun migrateLegacyPlaintext(context: Context, securePrefs: SharedPreferences) {
        if (securePrefs.contains(KEY_PRIVATE)) return
        val legacy = context.getSharedPreferences(LEGACY_PREFS, Context.MODE_PRIVATE)
        val id = legacy.getString(KEY_ID, null) ?: return
        val priv = legacy.getString(KEY_PRIVATE, null) ?: return
        val pub = legacy.getString(KEY_PUBLIC, null) ?: return
        securePrefs.edit()
            .putString(KEY_ID, id)
            .putString(KEY_PRIVATE, priv)
            .putString(KEY_PUBLIC, pub)
            .apply()
        legacy.edit().clear().apply()
    }

    private fun create(prefs: SharedPreferences): Identity {
        val id = UUID.randomUUID().toString().replace("-", "").lowercase()
        val kp = generate()
        prefs.edit()
            .putString(KEY_ID, id)
            .putString(KEY_PRIVATE, Base64.encodeToString(kp.private.encoded, Base64.NO_WRAP))
            .putString(KEY_PUBLIC, Base64.encodeToString(kp.public.encoded, Base64.NO_WRAP))
            .apply()
        return Identity(id, kp, computeFingerprint(kp.public))
    }

    private fun generate(): KeyPair {
        // Ed25519 要求 Android 11+ (API 30) 的 java.security 内置 provider；
        // 较老版本可换 BouncyCastle，骨架阶段先用平台默认。
        val gen = KeyPairGenerator.getInstance("Ed25519")
        gen.initialize(255, SecureRandom())
        return gen.generateKeyPair()
    }

    private fun decodePrivate(encoded: ByteArray): PrivateKey {
        val kf = java.security.KeyFactory.getInstance("Ed25519")
        return kf.generatePrivate(PKCS8EncodedKeySpec(encoded))
    }

    private fun decodePublic(encoded: ByteArray): PublicKey {
        val kf = java.security.KeyFactory.getInstance("Ed25519")
        return kf.generatePublic(X509EncodedKeySpec(encoded))
    }

    /**
     * 指纹 = SHA-256(raw 32-byte Ed25519 公钥) 前 16 字节 hex。
     *
     * JCA 返回的 Ed25519 公钥 `encoded` 是 X.509 SubjectPublicKeyInfo 格式；
     * 末尾 32 字节才是真正的公钥。这里做最小提取。
     */
    fun computeFingerprint(pub: PublicKey): String {
        val encoded = pub.encoded
        val raw = if (encoded.size >= 32) encoded.copyOfRange(encoded.size - 32, encoded.size) else encoded
        val digest = MessageDigest.getInstance("SHA-256").digest(raw)
        return digest.take(16).joinToString("") { "%02x".format(it) }
    }
}
