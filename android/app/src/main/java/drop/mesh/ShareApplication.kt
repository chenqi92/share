package drop.mesh

import android.app.Application
import drop.mesh.data.Identity
import drop.mesh.data.IdentityStore

class ShareApplication : Application() {
    lateinit var identity: Identity
        private set

    override fun onCreate() {
        super.onCreate()
        identity = IdentityStore.loadOrCreate(this)
    }
}
