import SwiftUI

/// 圆形 / 方形小按钮。size 32 默认。
/// `accent` 为 .lime 时填 lime 底 + ink 字；为 .ink 时反相。
public struct IconBtn: View {
    public enum Variant { case ghost, lime, ink, flame, outline }
    public enum ShapeKind { case circle, square }

    let symbol: String
    var size: CGFloat = 32
    var variant: Variant = .ghost
    var shape: ShapeKind = .circle
    /// false 时只渲染图标本体（不包 Button），用于外层已有 Button / PhotosPicker 提供点击的场景。
    var wrapInButton: Bool = true
    var action: () -> Void = {}

    @Environment(\.colorScheme) private var scheme

    public init(_ symbol: String, size: CGFloat = 32, variant: Variant = .ghost,
                shape: ShapeKind = .circle, wrapInButton: Bool = true,
                action: @escaping () -> Void = {}) {
        self.symbol = symbol
        self.size = size
        self.variant = variant
        self.shape = shape
        self.wrapInButton = wrapInButton
        self.action = action
    }

    public var body: some View {
        if wrapInButton {
            Button(action: action) { iconView }
                .buttonStyle(.plain)
        } else {
            iconView
        }
    }

    private var iconView: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg)
            .overlay(borderOverlay)
            .clipShape(maskShape)
    }

    private var bg: Color {
        switch variant {
        case .ghost:   return scheme == .dark ? Color.white.opacity(0.06) : MeshDropColor.ink06
        case .lime:    return MeshDropColor.lime
        case .ink:     return scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        case .flame:   return MeshDropColor.flame
        case .outline: return .clear
        }
    }

    private var fg: Color {
        switch variant {
        case .ghost:   return scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        case .lime:    return MeshDropColor.ink
        case .ink:     return scheme == .dark ? MeshDropColor.ink : MeshDropColor.paper
        case .flame:   return .white
        case .outline: return scheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink
        }
    }

    @ViewBuilder private var borderOverlay: some View {
        if variant == .outline {
            switch shape {
            case .circle: Circle().strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1)
            case .square: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(scheme == .dark ? MeshDropColor.dline : MeshDropColor.line, lineWidth: 1)
            }
        }
    }

    private var maskShape: AnyShape {
        switch shape {
        case .circle: return AnyShape(Circle())
        case .square: return AnyShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
