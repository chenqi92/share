import Foundation

/// watchOS Complication Extension 本地化查表入口。
///
/// Complication 是独立 widget extension target，进程内 `Bundle.main` 即本扩展自身 bundle，
/// 从中取 `Localizable.xcstrings`（zh-Hans 默认 + en）。
@inline(__always)
func MDC(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

@inline(__always)
func MDC(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
}
