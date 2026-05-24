import SwiftUI

/// MeshDrop 设计 token · 严格对齐 prompt §5。
///
/// 用法：`MeshDropColor.paper`、`MeshDropColor.lime`、`MeshDropColor.ink60` …
///
/// 暗模式不是简单反相；通过 `Color.adaptive(light:dark:)` 在 light/dark 间切换。
enum MeshDropColor {

    // MARK: ─── 油墨（文字 / 描边）─────────────────────────

    static let ink   = Color(hex: 0x0A0A0A)
    static let ink80 = Color(hex: 0x0A0A0A, opacity: 0.80)
    static let ink60 = Color(hex: 0x0A0A0A, opacity: 0.60)
    static let ink45 = Color(hex: 0x0A0A0A, opacity: 0.45)
    static let ink30 = Color(hex: 0x0A0A0A, opacity: 0.30)
    static let ink12 = Color(hex: 0x0A0A0A, opacity: 0.12)
    static let ink06 = Color(hex: 0x0A0A0A, opacity: 0.06)

    // MARK: ─── 纸张（背景）─────────────────────────────────

    static let paper  = Color(hex: 0xF5F2EC)   // 主背景（米白，不是纯白）
    static let paper2 = Color(hex: 0xEDE8DD)
    static let card   = Color.white
    static let line   = Color(hex: 0xE2DCCD)

    // MARK: ─── 暗模式 ─────────────────────────────────────

    static let dink   = Color(hex: 0x0E0C09)   // 暖黑，不是 #000
    static let dink2  = Color(hex: 0x181612)
    static let dink3  = Color(hex: 0x23201A)
    static let dpaper = Color(hex: 0xE8E3D6)
    static let dline  = Color.white.opacity(0.10)

    // MARK: ─── 三色语义 accent ────────────────────────────

    static let lime      = Color(hex: 0xDDF94B)
    static let limeDeep  = Color(hex: 0xA8C800)
    static let flame     = Color(hex: 0xFF5A2C)
    static let flameDeep = Color(hex: 0xC73E15)
    static let sky       = Color(hex: 0x4DB8FF)
    static let error     = Color(hex: 0xC4322B)

    // MARK: ─── 自适应组合（推荐主用）──────────────────────

    /// 主背景：light 报纸米白 / dark 暖黑
    static let background = Color.adaptive(light: paper, dark: dink)

    /// 卡片底：light 纯白 / dark dink2
    static let cardBg     = Color.adaptive(light: .white, dark: dink2)

    /// 次卡片：light paper2 / dark dink3
    static let cardBg2    = Color.adaptive(light: paper2, dark: dink3)

    /// 主文字
    static let textPrimary = Color.adaptive(light: ink, dark: dpaper)

    /// 次文字
    static let textSecondary = Color.adaptive(
        light: ink60,
        dark: Color.white.opacity(0.62)
    )

    /// 三级（mute）文字
    static let textMuted = Color.adaptive(
        light: ink45,
        dark: Color.white.opacity(0.45)
    )

    /// 分隔线
    static let divider = Color.adaptive(light: line, dark: dline)

    /// outgoing 气泡底色：light ink 黑 / dark **lime** 黄绿（重要！）
    static let outgoingBubble = Color.adaptive(light: ink, dark: lime)

    /// outgoing 气泡字色：light paper / dark ink
    static let outgoingText   = Color.adaptive(light: paper, dark: ink)

    /// incoming 气泡底色
    static let incomingBubble = Color.adaptive(
        light: .white,
        dark: Color.white.opacity(0.07)
    )

    /// lime 区域填充（light .32 / dark .10）
    static let limeFill = Color.adaptive(
        light: lime.opacity(0.32),
        dark: lime.opacity(0.10)
    )

    /// lime 区域填充（被选中态）
    static let limeFillSelected = Color.adaptive(
        light: lime.opacity(0.32),
        dark: lime.opacity(0.16)
    )

    /// sidebar / 玻璃面板背景（半透明）
    static let glassBg = Color.adaptive(
        light: Color.white.opacity(0.55),
        dark: Color.white.opacity(0.025)
    )
}

// MARK: ─── Color 扩展 ───────────────────────────────────

extension Color {
    /// 16 进制构造：`Color(hex: 0xDDF94B)`
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// 跨 light / dark 适配色。
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark]) != nil
            return NSColor(isDark ? dark : light)
        })
    }
}
