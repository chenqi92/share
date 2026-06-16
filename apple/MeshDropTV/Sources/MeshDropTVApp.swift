import SwiftUI
import MeshDropKit

@main
struct MeshDropTVApp: App {
    @StateObject private var engine = ShareEngine.shared

    var body: some Scene {
        WindowGroup {
            TVRoot()
                .environmentObject(engine)
                .onAppear {
                    #if DEBUG
                    if let route = ProcessInfo.processInfo.environment["MESHDROP_PREVIEW_ROUTE"] {
                        // 离线截图预览：只注入演示数据，不联网。release 由 #if DEBUG 排除。
                        engine.seedPreviewData(route: route)
                        return
                    }
                    #endif
                    engine.start()
                }
                .onDisappear { engine.stop() }
        }
    }
}
