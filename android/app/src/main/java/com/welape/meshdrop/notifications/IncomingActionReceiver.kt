package com.welape.meshdrop.notifications

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.welape.meshdrop.ShareApplication
import com.welape.meshdrop.data.PairingDecision
import java.util.UUID

/**
 * 通知 accept / decline 按钮的落点：把用户决定转交给 [com.welape.meshdrop.transport.ShareEngine]。
 *
 * - 文件 offer：engine.respondToFileOffer(offerId, accept)
 * - 配对请求：engine.respondToPairing(requestId, ALLOW_ONCE / REJECT)
 *
 * 处理完取消对应通知（accept 后续进度走前台 Service 那条；这条入站提醒可消失）。
 */
class IncomingActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val engine = ShareApplication.instance?.engine ?: return
        val idStr = intent.getStringExtra(EXTRA_ID) ?: return
        val id = runCatching { UUID.fromString(idStr) }.getOrNull() ?: return
        val notifId = intent.getIntExtra(EXTRA_NOTIF_ID, -1)

        when (intent.action) {
            ACTION_OFFER_ACCEPT -> engine.respondToFileOffer(id, true)
            ACTION_OFFER_DECLINE -> engine.respondToFileOffer(id, false)
            ACTION_PAIR_ACCEPT -> engine.respondToPairing(id, PairingDecision.ALLOW_ONCE)
            ACTION_PAIR_DECLINE -> engine.respondToPairing(id, PairingDecision.REJECT)
            else -> return
        }

        if (notifId >= 0) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(notifId)
        }
    }

    companion object {
        const val ACTION_OFFER_ACCEPT = "com.welape.meshdrop.action.OFFER_ACCEPT"
        const val ACTION_OFFER_DECLINE = "com.welape.meshdrop.action.OFFER_DECLINE"
        const val ACTION_PAIR_ACCEPT = "com.welape.meshdrop.action.PAIR_ACCEPT"
        const val ACTION_PAIR_DECLINE = "com.welape.meshdrop.action.PAIR_DECLINE"

        const val EXTRA_ID = "id"
        const val EXTRA_NOTIF_ID = "notif_id"
    }
}
