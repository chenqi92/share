package com.welape.meshdrop.notifications

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.welape.meshdrop.R

/**
 * 大文件传输保活 placeholder。本轮只声明，下一轮接 ShareEngine 时启用。
 */
class TransferForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannel(this)
        val notif: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("MeshDrop · 后台传输")
            .setContentText("正在保活以完成传输…")
            .setOngoing(true)
            .build()
        startForeground(NOTIF_ID, notif)
        return START_STICKY
    }

    companion object {
        private const val CHANNEL_ID = "transfer_running"
        private const val NOTIF_ID = 4301

        fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "后台传输",
                NotificationManager.IMPORTANCE_LOW,
            )
            nm.createNotificationChannel(channel)
        }
    }
}
