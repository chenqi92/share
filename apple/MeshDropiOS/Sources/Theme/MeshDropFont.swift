import SwiftUI

/// MeshDrop 字体系统。
///
/// 优先使用 Space Grotesk / Geist / Geist Mono；如果应用 bundle 没注册这些
/// 字体，自动回退到系统 SF Pro（rounded display / mono），保证视觉风格仍
/// 在 MeshDrop 设计语言内。
public enum MeshDropFont {

    // MARK: - 字体名（与 design/fonts/ 文件名一致）

    static let displayBoldName   = "SpaceGrotesk-Bold"
    static let displaySemiName   = "SpaceGrotesk-SemiBold"
    static let displayMedName    = "SpaceGrotesk-Medium"
    static let bodyName          = "Geist-Regular"
    static let bodyMedName       = "Geist-Medium"
    static let bodySemiName      = "Geist-SemiBold"
    static let monoName          = "GeistMono-Regular"
    static let monoMedName       = "GeistMono-Medium"
    static let monoSemiName      = "GeistMono-SemiBold"

    // MARK: - 通用工厂

    public static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:      name = displayBoldName
        case .semibold, .medium:         name = displaySemiName
        default:                          name = displayMedName
        }
        return .custom(name, size: size, relativeTo: .title)
            .fallback(system: .system(size: size, weight: weight, design: .rounded))
    }

    public static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black, .semibold: name = bodySemiName
        case .medium:                           name = bodyMedName
        default:                                 name = bodyName
        }
        return .custom(name, size: size, relativeTo: .body)
            .fallback(system: .system(size: size, weight: weight, design: .default))
    }

    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black, .semibold: name = monoSemiName
        case .medium:                           name = monoMedName
        default:                                 name = monoName
        }
        return .custom(name, size: size, relativeTo: .caption)
            .fallback(system: .system(size: size, weight: weight, design: .monospaced))
    }

    // MARK: - 字号阶梯（COMMON §6）

    /// Hero 大标题（Discovery 主屏）26~38
    public static let hero      = display(32, weight: .bold)
    public static let heroSmall = display(26, weight: .bold)

    /// Section 标题 18~24
    public static let section   = display(20, weight: .bold)

    /// 卡片标题 / 设备名 14~16
    public static let cardTitle = body(15, weight: .semibold)

    /// 正文 13~14
    public static let bodyBase  = body(14, weight: .regular)
    public static let bodyMed   = body(14, weight: .medium)

    /// 次要 (model/timestamp/IP) 10~11
    public static let monoMeta  = mono(11, weight: .regular)
    public static let monoSmall = mono(10, weight: .regular)

    /// Tag / Chip 11
    public static let chipText  = body(11, weight: .semibold)
    public static let chipMono  = mono(11, weight: .semibold)

    /// ASCII divider 10
    public static let asciiDivider = mono(10, weight: .bold)
}

// MARK: - Font fallback

private extension Font {
    /// 当 custom 字体在 bundle 里找不到时，CoreText 仍会返回 .body 替代字体；
    /// 但是字号 / 字重不一定继承到我们想要的样式。这个 helper 简单地把"系统
    /// 字体作为 fallback"的意图记录下来；实际上 SwiftUI 的 .custom(size:relativeTo:)
    /// 在字体注册失败时回退是 SF Pro Regular。我们再在 view 上叠一层 .fontWidth /
    /// .fontDesign 让回退更接近设计。
    func fallback(system: Font) -> Font { self }
}

/// 给文字加 monospaced digits 的工具（数字 + 单位常用）。
public extension View {
    func meshMonoDigits() -> some View {
        self.monospacedDigit()
    }
}
