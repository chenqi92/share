import SwiftUI
import ShareKit

@main
struct ShareiOSApp: App {
    @StateObject private var engine = ShareEngine.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .onAppear { engine.start() }
        }
    }
}
