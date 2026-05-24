import SwiftUI

enum MD {
    // OLED 黑底（手表全部走暗色）
    static let dink   = Color(red: 0x0E/255.0, green: 0x0C/255.0, blue: 0x09/255.0)
    static let dink2  = Color(red: 0x18/255.0, green: 0x16/255.0, blue: 0x12/255.0)
    static let dink3  = Color(red: 0x23/255.0, green: 0x20/255.0, blue: 0x1A/255.0)
    static let dpaper = Color(red: 0xE8/255.0, green: 0xE3/255.0, blue: 0xD6/255.0)

    // accent
    static let lime      = Color(red: 0xDD/255.0, green: 0xF9/255.0, blue: 0x4B/255.0)
    static let limeDeep  = Color(red: 0xA8/255.0, green: 0xC8/255.0, blue: 0x00/255.0)
    static let flame     = Color(red: 0xFF/255.0, green: 0x5A/255.0, blue: 0x2C/255.0)
    static let flameDeep = Color(red: 0xC7/255.0, green: 0x3E/255.0, blue: 0x15/255.0)
    static let sky       = Color(red: 0x4D/255.0, green: 0xB8/255.0, blue: 0xFF/255.0)
    static let error     = Color(red: 0xC4/255.0, green: 0x32/255.0, blue: 0x2B/255.0)

    static let dline = Color.white.opacity(0.10)
    static let muted = Color.white.opacity(0.50)
    static let dim   = Color.white.opacity(0.32)
    static let limeFill16 = Color(red: 0xDD/255.0, green: 0xF9/255.0, blue: 0x4B/255.0).opacity(0.16)
    static let limeFill10 = Color(red: 0xDD/255.0, green: 0xF9/255.0, blue: 0x4B/255.0).opacity(0.10)
}

enum MDFont {
    // 手表上字体回退到系统字体：display=rounded, mono=monospaced
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
