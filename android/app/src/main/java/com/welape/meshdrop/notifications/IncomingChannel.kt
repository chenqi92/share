package com.welape.meshdrop.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.welape.meshdrop.MainActivity
import com.welape.meshdrop.R
import com.welape.meshdrop.data.PendingFileOffer
import com.welape.meshdrop.data.PendingPairing
import java.util.UUID

/**
 * Heads-up「收到文件 / 配对请求」通知 channel。
 *
 * 由 [com.welape.meshdrop.ShareApplication] 订阅引擎 pendingFileOffers / pendingPairings 流驱动：
 * 新增一条 → [showFileOffer] / [showPairing] 弹高优先级通知；
 * 该条被消费（用户在通知或 app 内处理）→ [cancel] 撤掉。
 *
 * accept / decline 走 [IncomingActionReceiver]，无需打开 app 即可决定；点通知主体进 app。
 */
object IncomingChannel {
    private const val CHANNEL_ID = "incoming_file"

    /** 通知 id：用 UUID hash 映射到稳定区间，保证同一 offer/pairing 复用同一条通知。 */
    private const val NOTIF_BASE = 4200
    private const val NOTIF_SPAN = 90

    private fun notifIdFor(id: UUID): Int =
        NOTIF_BASE + Math.floorMod(id.hashCode(), NOTIF_SPAN)

    fun ensure(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.notif_channel_incoming_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = context.getString(R.string.notif_channel_incoming_desc)
            enableVibration(true)
        }
        nm.createNotificationChannel(channel)
    }

    /** 收到真实文件 offer：接收 / 拒绝 action + 点击进 app。 */
    fun showFileOffer(context: Context, offer: PendingFileOffer) {
        ensure(context)
        val notifId = notifIdFor(offer.id)
        val peer = offer.peer.name.ifEmpty { offer.peer.model ?: context.getString(R.string.notif_unknown_device) }

        val accept = actionIntent(
            context, IncomingActionReceiver.ACTION_OFFER_ACCEPT, offer.id, notifId,
        )
        val decline = actionIntent(
            context, IncomingActionReceiver.ACTION_OFFER_DECLINE, offer.id, notifId,
        )

        val builder = baseBuilder(
            context,
            context.getString(R.string.notif_offer_title, peer),
            context.getString(R.string.notif_offer_text, offer.fileName, offer.formattedSize),
        )
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(context.getString(R.string.notif_offer_bigtext, peer, offer.fileName, offer.formattedSize)),
            )
            .addAction(0, context.getString(R.string.notif_accept), accept)
            .addAction(0, context.getString(R.string.notif_reject), decline)

        notify(context, notifId, builder)
    }

    /** 收到真实配对请求：信任一次 / 拒绝 action + 点击进 app。 */
    fun showPairing(context: Context, pairing: PendingPairing) {
        ensure(context)
        val notifId = notifIdFor(pairing.id)
        val peer = pairing.peer.name.ifEmpty { pairing.peer.model ?: context.getString(R.string.notif_unknown_device) }

        val accept = actionIntent(
            context, IncomingActionReceiver.ACTION_PAIR_ACCEPT, pairing.id, notifId,
        )
        val decline = actionIntent(
            context, IncomingActionReceiver.ACTION_PAIR_DECLINE, pairing.id, notifId,
        )

        val builder = baseBuilder(
            context,
            context.getString(R.string.notif_pairing_title, peer),
            context.getString(R.string.notif_pairing_text),
        )
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText(context.getString(R.string.notif_pairing_bigtext, peer, pairing.peer.model ?: "?")),
            )
            .addAction(0, context.getString(R.string.notif_allow_once), accept)
            .addAction(0, context.getString(R.string.notif_reject), decline)

        notify(context, notifId, builder)
    }

    /** 撤掉某条 offer/pairing 的通知（已被处理 / 已从 pending 移除时调）。 */
    fun cancel(context: Context, id: UUID) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(notifIdFor(id))
    }

    private fun baseBuilder(
        context: Context,
        title: String,
        text: String,
    ): NotificationCompat.Builder {
        val openApp = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(text)
            .setContentIntent(openApp)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setAutoCancel(true)
    }

    private fun actionIntent(
        context: Context,
        action: String,
        id: UUID,
        notifId: Int,
    ): PendingIntent {
        val intent = Intent(context, IncomingActionReceiver::class.java).apply {
            this.action = action
            putExtra(IncomingActionReceiver.EXTRA_ID, id.toString())
            putExtra(IncomingActionReceiver.EXTRA_NOTIF_ID, notifId)
        }
        // requestCode 用 action+id 组合保证每个 action 的 PendingIntent 唯一，避免 extras 互相覆盖。
        val requestCode = (action + id.toString()).hashCode()
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun notify(context: Context, notifId: Int, builder: NotificationCompat.Builder) {
        // POST_NOTIFICATIONS 未授予（Android 13+）时 notify 会被系统静默丢弃，这里防御性判断避免无意义调用。
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(notifId, builder.build())
    }
}
