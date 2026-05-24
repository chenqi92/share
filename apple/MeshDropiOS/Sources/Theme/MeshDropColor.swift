import SwiftUI

/// MeshDrop 设计 token：颜色。
///
/// 暗模式不是 light 反相，而是按 COMMON §5 严格映射。
/// 所有页面只从这里取色，禁止 hardcode hex。
public enum MeshDropColor {

    // MARK: - Light

    /// 主文字 / 描边
    public static let ink     = Color(red: 0x0A/255, green: 0x0A/255, blue: 0x0A/255)
    public static let ink80   = Color.black.opacity(0.80)
    /// 次文字
    public static let ink60   = Color.black.opacity(0.60)
    /// 三级文字 / muted
    public static let ink45   = Color.black.opacity(0.45)
    public static let ink30   = Color.black.opacity(0.30)
    public static let ink12   = Color.black.opacity(0.12)
    public static let ink06   = Color.black.opacity(0.06)

    /// 报纸感的米白主背景
    public static let paper   = Color(red: 0xF5/255, green: 0xF2/255, blue: 0xEC/255)
    /// 次背景
    public static let paper2  = Color(red: 0xED/255, green: 0xE8/255, blue: 0xDD/255)
    /// 卡片纯白
    public static let card    = Color.white
    public static let line    = Color(red: 0xE2/255, green: 0xDC/255, blue: 0xCD/255)

    // MARK: - Dark

    /// 暗模式主背景 — 暖黑
    public static let dink    = Color(red: 0x0E/255, green: 0x0C/255, blue: 0x09/255)
    /// 暗模式次背景 / 卡片
    public static let dink2   = Color(red: 0x18/255, green: 0x16/255, blue: 0x12/255)
    public static let dink3   = Color(red: 0x23/255, green: 0x20/255, blue: 0x1A/255)
    /// 暗模式主文字
    public static let dpaper  = Color(red: 0xE8/255, green: 0xE3/255, blue: 0xD6/255)
    public static let dline   = Color.white.opacity(0.10)

    // MARK: - Accent (三色语义)

    public static let lime       = Color(red: 0xDD/255, green: 0xF9/255, blue: 0x4B/255)
    public static let limeDeep   = Color(red: 0xA8/255, green: 0xC8/255, blue: 0x00/255)
    public static let flame      = Color(red: 0xFF/255, green: 0x5A/255, blue: 0x2C/255)
    public static let flameDeep  = Color(red: 0xC7/255, green: 0x3E/255, blue: 0x15/255)
    public static let sky        = Color(red: 0x4D/255, green: 0xB8/255, blue: 0xFF/255)
    public static let error      = Color(red: 0xC4/255, green: 0x32/255, blue: 0x2B/255)
}

// MARK: - Scheme-aware 工具

/// 给一对 (light, dark) 返回当前外观下的颜色。
public func meshColor(_ scheme: ColorScheme, light: Color, dark: Color) -> Color {
    scheme == .dark ? dark : light
}

public extension EnvironmentValues {
    var meshBackground: Color { colorScheme == .dark ? MeshDropColor.dink   : MeshDropColor.paper }
    var meshSurface:    Color { colorScheme == .dark ? MeshDropColor.dink2  : MeshDropColor.card  }
    var meshSurface2:   Color { colorScheme == .dark ? MeshDropColor.dink3  : MeshDropColor.paper2 }
    var meshInk:        Color { colorScheme == .dark ? MeshDropColor.dpaper : MeshDropColor.ink   }
    var meshMuted:      Color { colorScheme == .dark ? Color.white.opacity(0.5) : MeshDropColor.ink45 }
    var meshHairline:   Color { colorScheme == .dark ? MeshDropColor.dline  : MeshDropColor.line  }
    /// outgoing 气泡填充：light=黑，dark=lime
    var meshOutgoingFill: Color { colorScheme == .dark ? MeshDropColor.lime : MeshDropColor.ink }
    /// outgoing 气泡文字：light=paper，dark=ink
    var meshOutgoingText: Color { colorScheme == .dark ? MeshDropColor.ink : MeshDropColor.paper }
    /// lime 区域填充透明值
    var meshLimeWash: Color { colorScheme == .dark ? MeshDropColor.lime.opacity(0.16) : MeshDropColor.lime.opacity(0.32) }
    var meshLimeWashSoft: Color { colorScheme == .dark ? MeshDropColor.lime.opacity(0.10) : MeshDropColor.lime.opacity(0.18) }
}
