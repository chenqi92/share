#if os(macOS)
import AppKit
import XCTest
@testable import MeshDropKit

@MainActor
final class SystemClipboardTests: XCTestCase {
    func testCopyPreservesFullTextAndReplacesPreviousContents() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("https://old.example", forType: .URL)
        let text = "  中文 / café 👋\nhttps://example.com?a=1&b=2\n\t尾部空格  "
        SystemClipboard.write(text, to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), text)
        XCTAssertNil(pasteboard.string(forType: .URL))
    }
}
#endif
