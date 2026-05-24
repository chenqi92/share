import SwiftUI

/// MeshDrop · 视觉 token（COMMON §5）。
/// visionOS 只跑 dark / passthrough，所以这里只列出在透明背景下需要的颜色。
enum MD {

    // MARK: light tokens（暗面板上偶尔需要的"纸感"高光）
    static let paper      = Color(red: 245/255, green: 242/255, blue: 236/255)
    static let paper2     = Color(red: 237/255, green: 232/255, blue: 221/255)
    static let card       = Color.white

    // MARK: ink（黑系，dark 反过来变 dpaper）
    static let ink        = Color(red: 10/255, green: 10/255, blue: 10/255)
    static func ink(_ a: Double) -> Color { Color.black.opacity(a) }

    // MARK: dark / passthrough
    static let dink       = Color(red: 14/255, green: 12/255, blue: 9/255)
    static let dink2      = Color(red: 24/255, green: 22/255, blue: 18/255)
    static let dink3      = Color(red: 35/255, green: 32/255, blue: 26/255)
    static let dpaper     = Color(red: 232/255, green: 227/255, blue: 214/255)
    static func dpaper(_ a: Double) -> Color { dpaper.opacity(a) }
    static let dline      = Color.white.opacity(0.10)

    // MARK: accent — 严格按语义使用
    static let lime       = Color(red: 221/255, green: 249/255, blue: 75/255)
    static let limeDeep   = Color(red: 168/255, green: 200/255, blue: 0/255)
    static let flame      = Color(red: 255/255, green: 90/255, blue: 44/255)
    static let flameDeep  = Color(red: 199/255, green: 62/255, blue: 21/255)
    static let sky        = Color(red: 77/255, green: 184/255, blue: 255/255)
    static let error      = Color(red: 196/255, green: 50/255, blue: 43/255)

    // MARK: glass 调色（visionOS 自己的 glass effect + 内层 tint）
    static let glassTint        = Color.white.opacity(0.04)
    static let glassStroke      = Color.white.opacity(0.14)
    static let glassStrokeHi    = Color.white.opacity(0.28)
    static let glassFloorTint   = Color.black.opacity(0.18)
}

/// Passthrough 背景渐变（用于 SpatialNearby 等页面的远景幕布）
struct MDPassthroughBackground: View {
    let hue: Double

    init(hue: Double = 28) { self.hue = hue }

    var body: some View {
        ZStack {
            // 远景：暖深色房间感
            LinearGradient(colors: [
                Color(hue: hue/360, saturation: 0.18, brightness: 0.10),
                Color(hue: (hue+18)/360, saturation: 0.12, brightness: 0.06),
                Color(hue: (hue+40)/360, saturation: 0.05, brightness: 0.04),
            ], startPoint: .top, endPoint: .bottom)

            // 模拟客厅斜方向的窗光
            RadialGradient(colors: [
                Color.white.opacity(0.07),
                Color.clear,
            ], center: UnitPoint(x: 0.18, y: 0.22), startRadius: 40, endRadius: 600)

            // 远处暖光斑
            RadialGradient(colors: [
                MD.flame.opacity(0.06),
                Color.clear,
            ], center: UnitPoint(x: 0.88, y: 0.75), startRadius: 40, endRadius: 460)
        }
        .ignoresSafeArea()
    }
}
