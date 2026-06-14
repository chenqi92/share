package com.welape.meshdrop.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.welape.meshdrop.MainActivity
import com.welape.meshdrop.R

/**
 * 大文件传输保活前台 Service。
 *
 * 由 [com.welape.meshdrop.ShareApplication] 订阅引擎 history / transferMetrics 流驱动：
 * - 有进行中传输（Transferring）→ [start]：startForeground 显示聚合进度通知；
 * - 进度变化 → 再次 [start] 携最新文案，复用同一 NOTIF_ID 原地刷新；
 * - 全部完成 / 失败 / 取消 → [stop]：stopForeground + stopSelf。
 *
 * foregroundServiceType 选 dataSync：LAN 文件收发属「上传/下载/数据传输」语义，
 * 对应 Android 14+ 的 FOREGROUND_SERVICE_DATA_SYNC（manifest 已声明权限 + type）。
 * connectedDevice 是给蓝牙/USB/伴侣设备等持续硬件连接场景，这里用不到。
 */
class TransferForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        ensureChannel(this)
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: getString(R.string.notif_transfer_default_title)
        val text = intent?.getStringExtra(EXTRA_TEXT) ?: getString(R.string.notif_transfer_default_text)
        val progress = intent?.getIntExtra(EXTRA_PROGRESS, -1) ?: -1
        val indeterminate = intent?.getBooleanExtra(EXTRA_INDETERMINATE, true) ?: true

        val notif = buildNotification(title, text, progress, indeterminate)
        startForegroundCompat(notif)
        // START_STICKY：进程被回收后系统尝试重启，但不重投 intent；重启时 intent==null，
        // 走默认占位文案，直到下次 start 用真实进度刷新。
        return START_STICKY
    }

    private fun buildNotification(
        title: String,
        text: String,
        progress: Int,
        indeterminate: Boolean,
    ): Notification {
        val openApp = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setPriority(NotificationCompat.PRIORITY_LOW)
        if (progress in 0..100 || indeterminate) {
            builder.setProgress(100, progress.coerceIn(0, 100), indeterminate)
        }
        return builder.build()
    }

    private fun startForegroundCompat(notif: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        private const val CHANNEL_ID = "transfer_running"
        private const val NOTIF_ID = 4301

        private const val ACTION_STOP = "com.welape.meshdrop.action.STOP_TRANSFER_SERVICE"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_TEXT = "text"
        private const val EXTRA_PROGRESS = "progress"
        private const val EXTRA_INDETERMINATE = "indeterminate"

        /**
         * 启动 / 刷新前台 Service。每次调用都更新前台通知文案与进度，复用同一 NOTIF_ID。
         * @param progress 0..100 的整体进度；<0 表示用 indeterminate 横条。
         */
        fun start(
            context: Context,
            title: String,
            text: String,
            progress: Int = -1,
            indeterminate: Boolean = progress < 0,
        ) {
            val intent = Intent(context, TransferForegroundService::class.java).apply {
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_INDETERMINATE, indeterminate)
            }
            // Android 8+ 后台启动前台 Service 必须用 startForegroundService，
            // 且须在 ~5s 内调 startForeground（onStartCommand 里已同步调）。
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** 停止前台 Service（全部传输结束时调）。 */
        fun stop(context: Context) {
            val intent = Intent(context, TransferForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            // 用 startService 把 STOP 投进去，让 Service 自己 stopForeground+stopSelf，
            // 比直接 stopService 更稳（保证先摘掉前台通知）。
            // 若 Service 当前未运行（如冷启动首帧无进行中传输），后台 startService 在 Android 8+
            // 可能抛 IllegalStateException —— 此时本就无前台要停，直接吞掉即可。
            try {
                context.startService(intent)
            } catch (_: IllegalStateException) {
            }
        }

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notif_channel_transfer_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.getString(R.string.notif_channel_transfer_desc)
                setShowBadge(false)
            }
            nm.createNotificationChannel(channel)
        }
    }
}
