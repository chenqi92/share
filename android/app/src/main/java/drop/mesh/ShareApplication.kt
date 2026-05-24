package drop.mesh

import android.app.Application
import drop.mesh.transport.ShareEngine

class ShareApplication : Application() {
    lateinit var engine: ShareEngine
        private set

    override fun onCreate() {
        super.onCreate()
        engine = ShareEngine(this)
    }
}
