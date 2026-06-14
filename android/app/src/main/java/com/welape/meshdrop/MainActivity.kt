package com.welape.meshdrop

import android.Manifest
import android.annotation.SuppressLint
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import androidx.core.content.IntentCompat
import com.welape.meshdrop.ui.MeshDropApp
import com.welape.meshdrop.ui.theme.MeshDropTheme

// 本 Activity 是纯 Compose 的 ComponentActivity，不含任何 Fragment；
// registerForActivityResult 走 activity（1.9.3）的 Activity Result API，与 fragment 版本无关。
// lint 的 InvalidFragmentVersionForActivityResult 针对的是传递引入的旧 fragment(1.1.0)，
// 对无 Fragment 的本类是误报，故在此抑制。
@SuppressLint("InvalidFragmentVersionForActivityResult")
class MainActivity : ComponentActivity() {

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) appEngine().start()
    }

    // Android 13+：POST_NOTIFICATIONS 是运行时权限；未授予时入站 offer / 传输进度通知会被系统静默丢弃。
    // 拒绝不阻断主流程（保活 Service 仍跑，只是没可见通知）。
    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { /* no-op */ }

    private fun appEngine() = (application as ShareApplication).engine
    private fun app() = application as ShareApplication

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MeshDropTheme {
                MeshDropApp(activity = this)
            }
        }
        ensurePermissionThenStart()
        ensureNotificationPermission()
        handleShareIntent(intent)
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        intent ?: return
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val type = intent.type ?: return
                if (type.startsWith("text/")) {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
                    app().setPendingShare(PendingShare.Text(text))
                } else {
                    val uri = IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                        ?: return
                    app().setPendingShare(PendingShare.Files(listOf(uri)))
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                    ?: return
                if (uris.isNotEmpty()) app().setPendingShare(PendingShare.Files(uris.toList()))
            }
        }
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
