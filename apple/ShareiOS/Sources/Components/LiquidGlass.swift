import SwiftUI

/// MeshDrop 的"液态玻璃"修饰符。
/// iOS 26+ 使用 `.glassEffect()`；17~25 回退 `.ultraThinMaterial`。
public struct LiquidGlass: ViewModifier {
    public enum Shape { case rect(CGFloat), capsule, circle }
    let shape: Shape
    let tint: Color?

    public init(shape: Shape = .rect(20), tint: Color? = nil) {
        self.shape = shape
        self.tint = tint
    }

    public func body(content: Content) -> some View {
        applyGlass(content)
    }

    @ViewBuilder
    private func applyGlass<V: View>(_ content: V) -> some View {
#if compiler(>=6.2)
        if #available(iOS 26, *) {
            applyiOS26(content)
        } else {
            applyFallback(content)
        }
#else
        applyFallback(content)
#endif
    }

#if compiler(>=6.2)
    @available(iOS 26, *)
    @ViewBuilder
    private func applyiOS26<V: View>(_ content: V) -> some View {
        switch shape {
        case .rect(let r):
            content.glassEffect(in: RoundedRectangle(cornerRadius: r, style: .continuous))
        case .capsule:
            content.glassEffect(in: Capsule(style: .continuous))
        case .circle:
            content.glassEffect(in: Circle())
        }
    }
#endif

    @ViewBuilder
    private func applyFallback<V: View>(_ content: V) -> some View {
        switch shape {
        case .rect(let r):
            content
                .background(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: r, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
        case .capsule:
            content
                .background(Capsule(style: .continuous).fill(.ultraThinMaterial))
                .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        case .circle:
            content
                .background(Circle().fill(.ultraThinMaterial))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }
}

public extension View {
    /// `.liquidGlass(.capsule)` 等。
    func liquidGlass(_ shape: LiquidGlass.Shape = .rect(20)) -> some View {
        modifier(LiquidGlass(shape: shape))
    }
}
