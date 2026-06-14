import Foundation

/// Widget Extension 本地化查表入口。
///
/// Widget 是独立 target / 独立 bundle，不能用主 app 的 `Bundle.main` 资源，
/// 必须从本扩展自己的 bundle 取 `Localizable.xcstrings`（zh-Hans 默认 + en）。
@inline(__always)
func MDW(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

@inline(__always)
func MDW(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
}
