import SwiftUI
import AppKit

/// MeshDrop 字体堆栈 · 严格对齐 prompt §6 字号阶梯。
///
/// 字体优先级：
///   display → "Space Grotesk" → fallback `SF Pro Display`（system rounded）
///   body    → "Geist"          → fallback system body
///   mono    → "Geist Mono"     → fallback `SF Mono`（system monospaced）
///
/// OFL 字体文件入 Resources/Fonts/ 后自动注册（见 `register()`）。
/// 若文件缺失自动回退到 system 字体，保证渲染不崩。
enum MeshDropFont {

    // MARK: 字号阶梯

    /// Hero 大标题（Discovery 主屏）— 26-38pt display 700
    static func hero(_ size: CGFloat = 32) -> Font {
        display(size: size, weight: .bold)
    }

    /// Section 标题 — 18-24pt display 700
    static func section(_ size: CGFloat = 22) -> Font {
        display(size: size, weight: .bold)
    }

    /// 卡片标题 / 设备名 — 14-16pt body/display 600
    static func cardTitle(_ size: CGFloat = 14) -> Font {
        body(size: size, weight: .semibold)
    }

    /// 正文 — 13-14pt body 400/500
    static func bodyText(_ size: CGFloat = 13) -> Font {
        body(size: size, weight: .regular)
    }

    /// 次要 mono — 10-11pt mono 400
    static func meta(_ size: CGFloat = 11) -> Font {
        mono(size: size, weight: .regular)
    }

    /// Tag / Chip — 11pt body or mono 600
    static func chip(_ size: CGFloat = 11, isMono: Bool = false) -> Font {
        isMono ? mono(size: size, weight: .semibold)
               : body(size: size, weight: .semibold)
    }

    /// ASCII divider label — 10pt mono 700 + uppercase + letterSpacing 1.5+
    static func divider(_ size: CGFloat = 10) -> Font {
        mono(size: size, weight: .bold)
    }

    // MARK: 原子

    static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        if registeredFamily(named: "Space Grotesk") {
            return .custom("Space Grotesk", size: size).weight(weight)
        }
        // SF Pro Display rounded 几何感最接近 Space Grotesk
        return .system(size: size, weight: weight, design: .rounded)
    }

    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if registeredFamily(named: "Geist") {
            return .custom("Geist", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    static func mono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if registeredFamily(named: "Geist Mono") {
            return .custom("Geist Mono", size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    // MARK: 注册

    /// 在 app 启动时调用一次。扫描 Bundle 内 .otf / .ttf，调用 CTFontManager 注册。
    /// 文件缺失静默跳过，自动回退 system 字体。
    static func register() {
        guard let resourcePath = Bundle.main.resourcePath else { return }
        let fontsDir = (resourcePath as NSString).appendingPathComponent("Fonts")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: fontsDir) else { return }
        for file in files where file.hasSuffix(".otf") || file.hasSuffix(".ttf") {
            let url = URL(fileURLWithPath: (fontsDir as NSString).appendingPathComponent(file))
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: 私有

    private static var familyCache: [String: Bool] = [:]

    private static func registeredFamily(named name: String) -> Bool {
        if let cached = familyCache[name] { return cached }
        let available = NSFontManager.shared.availableFontFamilies.contains(name)
        familyCache[name] = available
        return available
    }
}

// MARK: ─── 便利 modifier ────────────────────────────────

extension View {
    /// `Text("ZX8K · L72M").meshMono(11)` —— mono + tracking 风
    func meshMono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> some View {
        self.font(MeshDropFont.mono(size: size, weight: weight))
    }

    /// 全大写 + letterSpacing 风（mono uppercase tag）
    func meshTag() -> some View {
        self.font(MeshDropFont.divider())
            .textCase(.uppercase)
            .tracking(1.5)
    }
}
