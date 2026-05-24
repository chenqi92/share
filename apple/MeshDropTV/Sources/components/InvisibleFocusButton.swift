import SwiftUI

/// 用完全自定义的 ButtonStyle 接管渲染，从根上避免任何系统 focus halo / hover lift。
private struct _CleanButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

/// tvOS focus 友好的按钮：完全用 caller 提供的 @FocusState 表达焦点，
/// 不带任何系统 hover halo / lift 视觉。
struct InvisibleFocusButton<Value: Hashable, Content: View>: View {
    var isFocused: FocusState<Value?>.Binding
    var value: Value
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
        }
        .buttonStyle(_CleanButtonStyle())
        .focused(isFocused, equals: value)
        .focusEffectDisabled()
    }
}
