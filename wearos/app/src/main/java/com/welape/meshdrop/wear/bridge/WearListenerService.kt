package com.welape.meshdrop.wear.bridge

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * 后台进程仍存活时，phone 端推 /meshdrop/evt 由本 Service 接收。
 * 进程内的 WearSessionClient 自己也注册了 listener，两路冗余以避免事件丢失。
 */
class WearListenerService : WearableListenerService() {

    override fun onMessageReceived(messageEvent: MessageEvent) {
        when (messageEvent.path) {
            BridgePaths.EVT, BridgePaths.CMD_RESP -> {
                WearEngineProxy.peekInstance()?.injectMessage(messageEvent.path, messageEvent.data)
            }
        }
    }
}
