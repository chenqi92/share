import SwiftUI
import ShareKit

@main
struct ShareMacApp: App {
    @StateObject private var engine = ShareEngine.shared

    var body: some Scene {
        WindowGroup("MeshDrop") {
            ContentView()
                .environmentObject(engine)
                .onAppear { engine.start() }
                .frame(minWidth: 480, minHeight: 360)
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }   // 去掉 ⌘N
        }
    }
}
