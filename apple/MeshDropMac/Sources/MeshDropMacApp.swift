import SwiftUI
import AppKit
import MeshDropKit

@main
struct MeshDropMacApp: App {
    @StateObject private var state = AppState()
    @StateObject private var gateway = GatewayService()

    init() {
        MeshDropFont.register()
        DispatchQueue.main.async {
            ScreenshotRunner.runIfRequested()
        }
    }

    var body: some Scene {
        WindowGroup("MeshDrop") {
            AppShell()
                .environmentObject(state)
                .environmentObject(gateway)
                .preferredColorScheme(nil)   // 跟随系统
                .onAppear {
                    ShareEngine.shared.start()
                    IncomingNotifier.startShared(engine: ShareEngine.shared)
                    gateway.startIfEnabled()
                }
                .onDisappear {
                    ShareEngine.shared.stop()
                    gateway.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("menu.pairNewDevice") {
                    state.tab = .pairing
                }
                .keyboardShortcut("p", modifiers: [.option, .shift])
            }
        }

        Settings {
            SettingsPage()
                .environmentObject(state)
                .environmentObject(gateway)
                .frame(minWidth: 720, minHeight: 560)
        }

        MenuBarExtra {
            MenuBarDropdown()
                .environmentObject(state)
                .padding(8)
        } label: {
            // 菜单栏 icon — 复用 MeshDropMark，确保 lime dot 在
            Image(nsImage: MeshDropMacApp.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// 渲染 18×18 的菜单栏图标（含 lime dot）。
    static var menuBarIcon: NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        let stroke = NSColor.labelColor
        stroke.setStroke()
        let lw: CGFloat = 1.4

        let lefRect  = NSRect(x: 1, y: 4, width: 9, height: 9)
        let rightRect = NSRect(x: 8, y: 4, width: 9, height: 9)
        NSBezierPath(ovalIn: lefRect).lineWidth = lw
        NSBezierPath(ovalIn: lefRect).stroke()
        NSBezierPath(ovalIn: rightRect).lineWidth = lw
        NSBezierPath(ovalIn: rightRect).stroke()

        NSColor(MeshDropColor.lime).setFill()
        NSBezierPath(ovalIn: NSRect(x: 7.5, y: 7.5, width: 3, height: 3)).fill()

        return img
    }
}
