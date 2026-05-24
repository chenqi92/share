import SwiftUI
import Foundation

/// 在 MESHDROP_SCREENSHOT=1 时 ScrollView 不能被 ImageRenderer 渲染，所以
/// 退化为 VStack。运行时使用 ScrollView，截图渲染时使用 VStack。
struct PageScroll<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if Self.isScreenshot {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                content
            }
        }
    }

    static var isScreenshot: Bool {
        ProcessInfo.processInfo.environment["MESHDROP_SCREENSHOT"] == "1"
    }
}
