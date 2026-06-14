import Foundation

/// 本地化查表入口。
///
/// 为什么不直接用 `Text("key")`：SwiftUI 的 `Text` 会把字面量当 `LocalizedStringKey` 自动查表，
/// 但本工程的 key 是点分命名空间（如 `discovery.title`），且很多地方需要带参数插值
/// （如 `已发送 %d 个文件给 %@`），用一个显式函数统一从 `Localizable.xcstrings` 取值更可控、
/// 也便于静态核对每个 key 都存在。
///
/// 资源：各 target 自带 `Resources/Localizable.xcstrings`，含 zh-Hans（默认）+ en 两份。
@inline(__always)
func MD(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

/// 带格式参数的本地化查表（参数顺序由各语言文件的 `%@` / `%d` 决定）。
@inline(__always)
func MD(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .main, comment: ""), arguments: args)
}
