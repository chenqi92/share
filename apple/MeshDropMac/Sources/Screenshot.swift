import SwiftUI
import AppKit

/// 离线渲染 12 页 × light/dark → PNG。
/// 在 `MeshDropMacApp.init()` 中检测 env var `MESHDROP_SCREENSHOT=1` 启动；
/// 完成后立即 exit(0)，不进入 GUI 主循环。
@MainActor
enum ScreenshotRunner {

    static func runIfRequested() {
        guard ProcessInfo.processInfo.environment["MESHDROP_SCREENSHOT"] == "1" else { return }
        guard let outDir = ProcessInfo.processInfo.environment["MESHDROP_SCREENSHOT_DIR"]
        else {
            fputs("MESHDROP_SCREENSHOT=1 requires MESHDROP_SCREENSHOT_DIR\n", stderr)
            exit(2)
        }
        try? FileManager.default.createDirectory(atPath: outDir,
                                                 withIntermediateDirectories: true)

        let pages: [(MainTab, String)] = [
            (.discovery,  "discovery"),
            (.chat,       "chat"),
            (.transfers,  "transfers"),
            (.history,    "history"),
            (.clipboard,  "clipboard"),
            (.trust,      "trust"),
            (.settings,   "settings"),
            (.pairing,    "pairing"),
            (.onboarding, "onboarding"),
            (.receive,    "receive"),
            (.menubar,    "menubar"),
            (.dragdrop,   "dragdrop"),
        ]
        let themes: [(ColorScheme, String)] = [
            (.light, "light"),
            (.dark,  "dark"),
        ]
        let width: CGFloat  = 1440
        let height: CGFloat = 900

        for (tab, pageSlug) in pages {
            for (scheme, themeSlug) in themes {
                let state = AppState()
                state.tab = tab
                let view = AppShell()
                    .environmentObject(state)
                    .frame(width: width, height: height)
                    .environment(\.colorScheme, scheme)
                    .preferredColorScheme(scheme)

                let renderer = ImageRenderer(content: view)
                renderer.scale = 2  // @2x retina
                renderer.proposedSize = ProposedViewSize(width: width, height: height)

                guard let nsImage = renderer.nsImage else {
                    fputs("ImageRenderer returned nil for \(pageSlug) \(themeSlug)\n", stderr)
                    continue
                }

                let filename = "macos-\(pageSlug)-\(themeSlug).png"
                let outPath = (outDir as NSString).appendingPathComponent(filename)
                if writePNG(image: nsImage, to: outPath) {
                    fputs("✓ \(filename)\n", stderr)
                } else {
                    fputs("✗ \(filename) write failed\n", stderr)
                }
            }
        }

        exit(0)
    }

    private static func writePNG(image: NSImage, to path: String) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let rep  = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:])
        else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }
}
