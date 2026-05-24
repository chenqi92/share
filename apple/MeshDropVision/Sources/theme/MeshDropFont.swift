import SwiftUI

/// COMMON §6 字号阶梯。
/// 没有 Space Grotesk / Geist 字体文件入仓时，回退到系统等价（rounded + monospaced），
/// 至少保留字阶与字距。后续把 OFL 字体放入 Resources/Fonts/ 即可在此切换 family。
enum MDFont {

    // MARK: family — 当前缺字体文件，全部走系统对应族
    private static let displayFamily = "SpaceGrotesk-Bold"     // 待嵌入：Resources/Fonts/
    private static let bodyFamily    = "Geist-Regular"          // 待嵌入
    private static let monoFamily    = "GeistMono-Regular"      // 待嵌入

    // 当字体未注册时，回退到系统几何感字体（visionOS 上更接近 Space Grotesk 的密度）
    private static func displayFallback(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    private static func bodyFallback(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    private static func monoFallback(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: hero / section
    static let hero        = displayFallback(34, .bold)
    static let heroSmall   = displayFallback(28, .bold)
    static let section     = displayFallback(22, .bold)
    static let cardTitle   = bodyFallback(15, .semibold)
    static let body        = bodyFallback(13.5, .regular)
    static let bodyEmph    = bodyFallback(13.5, .semibold)

    static let label       = bodyFallback(12, .medium)
    static let micro       = monoFallback(10.5, .regular)
    static let microHi     = monoFallback(10.5, .semibold)
    static let chip        = bodyFallback(11, .semibold)
    static let chipMono    = monoFallback(11, .semibold)

    /// ASCII Divider 用：mono uppercase + 字距 1.5+。SwiftUI 自带 tracking 即可。
    static let divider     = monoFallback(10.5, .semibold)
}

extension View {
    /// 给数字 / IP / 时间戳等 mono 字段加字距，营造终端感。
    func mdMonoTracking() -> some View {
        self.tracking(0.6)
    }

    /// ASCII divider 文本附加大字距 + uppercase。
    func mdDividerLabel() -> some View {
        self.tracking(2.2)
            .textCase(.uppercase)
    }
}
