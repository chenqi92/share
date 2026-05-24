package com.welape.meshdrop.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.welape.meshdrop.MainActivity
import com.welape.meshdrop.R

/**
 * Heads-up incoming file 通知 channel + 三按钮 mock。
 * 真实接入引擎在下一轮；本轮供截图 + 触发演示。
 */
object IncomingChannel {
    private const val CHANNEL_ID = "incoming_file"
    private const val NOTIF_ID = 4201

    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "收到文件 · Incoming",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "其他设备发来的文件请求"
            enableVibration(true)
        }
        nm.createNotificationChannel(channel)
    }

    fun showIncomingMock(context: Context, peer: String, fileName: String, size: String) {
        ensure(context)
        val openAppIntent = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val accept = PendingIntent.getActivity(
            context, 1,
            Intent(context, MainActivity::class.java).putExtra("mock_action", "accept"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val reject = PendingIntent.getActivity(
            context, 2,
            Intent(context, MainActivity::class.java).putExtra("mock_action", "reject"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val toPhotos = PendingIntent.getActivity(
            context, 3,
            Intent(context, MainActivity::class.java).putExtra("mock_action", "to_photos"),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("$peer 发来文件")
            .setContentText("$fileName · $size")
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("$peer · MeshDrop\n$fileName · $size\n点接收即可保存"),
            )
            .setContentIntent(openAppIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .addAction(0, "接收", accept)
            .addAction(0, "拒绝", reject)
            .addAction(0, "保存到相册", toPhotos)
            .setAutoCancel(true)

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, builder.build())
    }
}
