import SwiftUI

/// tvOS 的字体阶梯：display 56 / 44 / 36 / 28 / 22；body 22 / 18；mono 18 / 14。
/// 字体文件没入仓，全部 fallback 到系统字体 + design 选项以保留几何感。
enum MeshDropFont {
    static func displayHero() -> Font   { .system(size: 64, weight: .bold,    design: .default) }
    static func displayXL()   -> Font   { .system(size: 56, weight: .bold,    design: .default) }
    static func displayL()    -> Font   { .system(size: 44, weight: .bold,    design: .default) }
    static func displayM()    -> Font   { .system(size: 36, weight: .bold,    design: .default) }
    static func displayS()    -> Font   { .system(size: 28, weight: .bold,    design: .default) }

    static func bodyL()   -> Font   { .system(size: 24, weight: .regular, design: .default) }
    static func bodyM()   -> Font   { .system(size: 20, weight: .regular, design: .default) }
    static func bodyS()   -> Font   { .system(size: 18, weight: .regular, design: .default) }

    static func monoXL()  -> Font   { .system(size: 40, weight: .bold,    design: .monospaced) }
    static func monoL()   -> Font   { .system(size: 28, weight: .bold,    design: .monospaced) }
    static func monoM()   -> Font   { .system(size: 20, weight: .semibold,design: .monospaced) }
    static func monoS()   -> Font   { .system(size: 16, weight: .semibold,design: .monospaced) }
    static func monoTag() -> Font   { .system(size: 14, weight: .bold,    design: .monospaced) }
}

/// 大写 mono tag 修饰器 —— 用于 ONLINE / E2E / LAN ONLY / READY 等状态字
extension View {
    func monoTag(_ color: Color = MeshDropColor.dpaperMute) -> some View {
        self
            .font(MeshDropFont.monoTag())
            .tracking(2.4)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}
