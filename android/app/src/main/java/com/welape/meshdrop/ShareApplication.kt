package com.welape.meshdrop

import android.app.Application
import com.welape.meshdrop.transport.ShareEngine

class ShareApplication : Application() {
    lateinit var engine: ShareEngine
        private set

    override fun onCreate() {
        super.onCreate()
        engine = ShareEngine(this)
    }
}
