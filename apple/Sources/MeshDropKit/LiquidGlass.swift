import SwiftUI

/// iOS 26 / macOS Tahoe 引入了 Liquid Glass：`.glassEffect()` API。
/// 跨 iOS / macOS / iPadOS 共用，根据可用性自动选择最佳呈现。
///
/// 用法：
/// ```
/// MyCard()
///     .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
/// ```
///
/// - iOS 26+ / macOS 26+ (Tahoe)：调用原生 `.glassEffect(.regular, in: shape)`，
///   完整 Liquid Glass 折射 / 高光 / 边缘效果。
/// - 旧版本：自动回退到 `.ultraThinMaterial`。
///
/// 编译要求：Xcode 26+ (Swift 6.2+) 才会启用 Liquid Glass 分支；旧 Xcode
/// 自动跳过该分支。
public extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S) -> some View {
        // visionOS SDK 把 `.glassEffect` 标为 unavailable，需要在编译期就排除，
        // 不能仅靠 `@available` 运行期门。其余平台仍按 26.0 可用性回退。
        #if compiler(>=6.2) && !os(visionOS)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
        #else
        self.background(.ultraThinMaterial, in: shape)
        #endif
    }

    /// 容器版本：让一组子视图作为 Liquid Glass 元素协同变形。iOS/macOS/tvOS 26+
    /// 用 `GlassEffectContainer`，visionOS / 旧版退化为普通 ZStack。
    @ViewBuilder
    func liquidGlassContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        #if compiler(>=6.2) && !os(visionOS)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
            GlassEffectContainer { content() }
        } else {
            ZStack { content() }
        }
        #else
        ZStack { content() }
        #endif
    }
}
