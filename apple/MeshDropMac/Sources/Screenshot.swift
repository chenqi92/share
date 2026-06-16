import SwiftUI
import AppKit
import ImageIO
import UniformTypeIdentifiers
import MeshDropKit

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
                // 注入演示数据：设备 / 历史 / 信任 / 吞吐；receive / pairing 页注入对应待审项。
                #if DEBUG
                let seedRoute: String
                switch tab {
                case .receive: seedRoute = "receive"
                case .pairing: seedRoute = "pairing"
                default:       seedRoute = "discover"
                }
                ShareEngine.shared.seedPreviewData(route: seedRoute)
                // 本机名默认取宿主机名（可能是中文），截图里统一成本地化演示名。
                let zhUI = (Bundle.main.preferredLocalizations.first ?? "en").lowercased().hasPrefix("zh")
                ShareEngine.shared.displayName = zhUI ? "我的 MacBook" : "My MacBook"
                #endif
                let state = AppState()
                state.tab = tab
                #if DEBUG
                state.snapshotFromEngineForScreenshot()
                #endif
                let view = AppShell()
                    .environmentObject(state)
                    .environmentObject(GatewayService())
                    .frame(width: width, height: height)
                    .environment(\.colorScheme, scheme)
                    .preferredColorScheme(scheme)

                let renderer = ImageRenderer(content: view)
                renderer.proposedSize = ProposedViewSize(width: width, height: height)

                let filename = "macos-\(pageSlug)-\(themeSlug).png"
                let outPath = (outDir as NSString).appendingPathComponent(filename)
                let scale: CGFloat = 2  // @2x retina → 2880×1800
                var wrote = false
                renderer.render { size, renderInContext in
                    let pxW = Int(size.width * scale)
                    let pxH = Int(size.height * scale)
                    guard pxW > 0, pxH > 0,
                          let ctx = CGContext(data: nil, width: pxW, height: pxH,
                                              bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                    else { return }
                    ctx.scaleBy(x: scale, y: scale)
                    renderInContext(ctx)
                    if let cg = ctx.makeImage() {
                        wrote = writePNG(cgImage: cg, to: outPath)
                    }
                }
                fputs(wrote ? "✓ \(filename)\n" : "✗ \(filename) render/write failed\n", stderr)
            }
        }

        exit(0)
    }

    private static func writePNG(cgImage: CGImage, to path: String) -> Bool {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let dest = CGImageDestinationCreateWithURL(
            url, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(dest, cgImage, nil)
        return CGImageDestinationFinalize(dest)
    }
}
