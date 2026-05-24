package com.welape.meshdrop.wear

import android.app.Application
import com.welape.meshdrop.wear.bridge.WearEngineProxy

class MeshDropWearApp : Application() {
    override fun onCreate() {
        super.onCreate()
        WearEngineProxy.init(this).start()
    }

    override fun onTerminate() {
        WearEngineProxy.peekInstance()?.stop()
        super.onTerminate()
    }
}
