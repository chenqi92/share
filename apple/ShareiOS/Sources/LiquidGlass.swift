import SwiftUI

/// iOS 26 / macOS Tahoe 引入了 Liquid Glass：`.glassEffect()` API。
///
/// 用法：
/// ```
/// MyCard()
///     .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
/// ```
///
/// 在 iOS 26+ 自动使用 `.glassEffect(.regular, in: shape)`；旧版本回退到
/// `.ultraThinMaterial`，保证 iOS 17 / 18 / 19 / 25 上仍有近似的玻璃质感。
///
/// 编译要求：用 Xcode 26+ (Swift 6.2+) 构建才会启用 Liquid Glass 分支；旧 SDK
/// 编译会自动降级到 material（无运行期影响）。
extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }

    /// 容器版本：让一组子视图作为 Liquid Glass 元素协同变形。iOS 26+ 用
    /// `GlassEffectContainer`，旧版退化为普通 ZStack。
    @ViewBuilder
    func liquidGlassContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer { content() }
        } else {
            ZStack { content() }
        }
        #else
        ZStack { content() }
        #endif
    }
}
