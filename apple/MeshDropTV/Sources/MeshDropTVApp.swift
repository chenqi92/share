import SwiftUI
import MeshDropKit

@main
struct MeshDropTVApp: App {
    @StateObject private var engine = ShareEngine.shared

    var body: some Scene {
        WindowGroup {
            TVRoot()
                .environmentObject(engine)
                .onAppear { engine.start() }
                .onDisappear { engine.stop() }
        }
    }
}
