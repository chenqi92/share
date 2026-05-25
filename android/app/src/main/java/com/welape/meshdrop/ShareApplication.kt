package com.welape.meshdrop

import android.app.Application
import com.welape.meshdrop.bridge.WearEventPusher
import com.welape.meshdrop.transport.ShareEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ShareApplication : Application() {
    lateinit var engine: ShareEngine
        private set

    /** Wear companion bridge：推 engine 事件给 wear。phone 没装 Wear 也安全（无 connected nodes）。 */
    lateinit var wearEventPusher: WearEventPusher
        private set

    /** 来自外部 Share 菜单的待发内容；UI 监听到非空时弹"选目标 peer"对话框。 */
    private val _pendingShare = MutableStateFlow<PendingShare?>(null)
    val pendingShare: StateFlow<PendingShare?> = _pendingShare.asStateFlow()

    fun setPendingShare(share: PendingShare) {
        _pendingShare.value = share
    }

    fun consumePendingShare(): PendingShare? {
        val v = _pendingShare.value
        _pendingShare.value = null
        return v
    }

    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    override fun onCreate() {
        super.onCreate()
        engine = ShareEngine(this)
        wearEventPusher = WearEventPusher(this, engine)
        applicationScope.launch {
            wearEventPusher.start()
        }
    }

    override fun onTerminate() {
        wearEventPusher.stop()
        engine.stop()
        super.onTerminate()
    }
}
