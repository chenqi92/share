package com.welape.meshdrop

import android.app.Application
import com.welape.meshdrop.bridge.WearEventPusher
import com.welape.meshdrop.data.HistoryItem
import com.welape.meshdrop.data.TransferDirection
import com.welape.meshdrop.data.TransferMetrics
import com.welape.meshdrop.data.TransferStatus
import com.welape.meshdrop.notifications.IncomingChannel
import com.welape.meshdrop.notifications.TransferForegroundService
import com.welape.meshdrop.transport.ShareEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import java.util.UUID

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
        instance = this
        wearEventPusher = WearEventPusher(this, engine)
        applicationScope.launch {
            wearEventPusher.start()
        }
        // 订阅引擎流，驱动系统通知 / 前台保活 Service。engine.start() 由 MainActivity 取权限后调用；
        // 这里提前 collect 没问题——start 前各 StateFlow 都是空，不会发通知。
        observeIncoming()
        observeTransfers()
    }

    override fun onTerminate() {
        wearEventPusher.stop()
        engine.stop()
        super.onTerminate()
    }

    /**
     * 订阅入站 offer / 配对请求：pending 列表里新增的发系统通知，移除的撤掉通知。
     * 用「上一帧 id 集合」对比 diff，避免同一条被重复 notify（列表里任一项变动都会重发整列表）。
     */
    private fun observeIncoming() {
        applicationScope.launch {
            var lastOfferIds = emptySet<UUID>()
            engine.pendingFileOffers.collect { offers ->
                val curIds = offers.map { it.id }.toSet()
                for (offer in offers) {
                    if (offer.id !in lastOfferIds) {
                        IncomingChannel.showFileOffer(applicationContext, offer)
                    }
                }
                for (goneId in lastOfferIds - curIds) {
                    IncomingChannel.cancel(applicationContext, goneId)
                }
                lastOfferIds = curIds
            }
        }
        applicationScope.launch {
            var lastPairIds = emptySet<UUID>()
            engine.pendingPairings.collect { pairings ->
                val curIds = pairings.map { it.id }.toSet()
                for (p in pairings) {
                    if (p.id !in lastPairIds) {
                        IncomingChannel.showPairing(applicationContext, p)
                    }
                }
                for (goneId in lastPairIds - curIds) {
                    IncomingChannel.cancel(applicationContext, goneId)
                }
                lastPairIds = curIds
            }
        }
    }

    /**
     * 订阅 history + transferMetrics，聚合出「是否有进行中传输 + 整体进度 + 当前速率」，
     * 据此启停前台保活 Service：无进行中传输 → stop；有 → start/刷新进度文案。
     */
    private fun observeTransfers() {
        applicationScope.launch {
            engine.history
                .combine(engine.transferMetrics) { history, metrics ->
                    summarize(history, metrics)
                }
                .distinctUntilChanged()
                .collect { summary ->
                    if (summary == null) {
                        TransferForegroundService.stop(applicationContext)
                    } else {
                        TransferForegroundService.start(
                            applicationContext,
                            title = summary.title,
                            text = summary.text,
                            progress = summary.progress,
                            indeterminate = summary.indeterminate,
                        )
                    }
                }
        }
    }

    private data class TransferSummary(
        val title: String,
        val text: String,
        val progress: Int,
        val indeterminate: Boolean,
    )

    /** 把进行中（Transferring）的传输项聚合成一条前台通知摘要；无进行中项返回 null。 */
    private fun summarize(
        history: List<HistoryItem>,
        metrics: Map<UUID, TransferMetrics>,
    ): TransferSummary? {
        val active = history.filter { it.status is TransferStatus.Transferring }
        if (active.isEmpty()) return null

        var done = 0L
        var total = 0L
        var bytesPerSec = 0.0
        for (item in active) {
            val st = item.status as TransferStatus.Transferring
            done += st.bytesDone
            total += st.bytesTotal
            metrics[item.id]?.let { bytesPerSec += it.bytesPerSec }
        }

        val progress = if (total > 0) ((done * 100) / total).toInt().coerceIn(0, 100) else -1
        val indeterminate = total <= 0

        val anyOut = active.any { it.direction == TransferDirection.OUTGOING }
        val anyIn = active.any { it.direction == TransferDirection.INCOMING }
        val verb = when {
            anyOut && anyIn -> "传输中"
            anyOut -> "发送中"
            else -> "接收中"
        }

        val title = if (active.size == 1) {
            "MeshDrop · $verb"
        } else {
            "MeshDrop · $verb（${active.size} 个文件）"
        }
        val speed = if (bytesPerSec > 1.0) " · ${formatSpeed(bytesPerSec)}" else ""
        val text = if (progress >= 0) "$progress%$speed" else "正在保活以完成传输…"

        return TransferSummary(title, text, progress, indeterminate)
    }

    private fun formatSpeed(bytesPerSec: Double): String {
        val kb = bytesPerSec / 1024.0
        if (kb < 1024) return "%.0f KB/s".format(kb)
        return "%.1f MB/s".format(kb / 1024.0)
    }

    companion object {
        /**
         * 进程内单例引用：供 BroadcastReceiver 等无 DI 的入口拿到 engine。
         * onCreate 早于任何组件，使用前必非空（除非进程被杀后系统先拉起 Receiver——
         * 此时系统也会先建 Application，instance 仍可用）。
         */
        @Volatile
        var instance: ShareApplication? = null
            private set
    }
}
