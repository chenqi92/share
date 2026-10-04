import XCTest
@testable import MeshDropKit

final class MarkdownDocumentTests: XCTestCase {
    func testStructuredMarkdownKeepsHierarchyFormattingAndCode() {
        let source = """
        # 标题

        第一行
        第二行 **粗体** ~~删除~~ [链接](https://example.com)

        3. 外层
           - [x] 内层任务

        > 引用

        ```swift
        let value = "中文 👋"
        print(value)
        ```

        | 名称 | 数量 |
        | --- | ---: |
        | 图片 | 2 |
        """
        let blocks = MarkdownDocument(source).blocks
        XCTAssertEqual(blocks[0].kind, .header(level: 1))
        XCTAssertTrue(String(blocks[1].text.characters).contains("第一行\n第二行"))
        XCTAssertTrue(blocks[1].text.runs.contains { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true })
        let list = blocks.first { $0.kind == .orderedList }
        XCTAssertEqual(list?.children.first?.kind, .listItem(ordinal: 3))
        XCTAssertEqual(list?.children.first?.children.last?.kind, .unorderedList)
        let code = blocks.first { if case .codeBlock = $0.kind { return true }; return false }
        XCTAssertEqual(String(code!.text.characters), "let value = \"中文 👋\"\nprint(value)\n")
        let table = blocks.last!
        guard case .table(let columns) = table.kind else { return XCTFail("Expected table") }
        XCTAssertEqual(columns.map(\.alignment), [.left, .right])
        XCTAssertEqual(table.children.count, 2)
        XCTAssertEqual(table.children.last?.children.count, 2)
    }

    func testUntrustedMarkdownCannotOpenLocalFilesOrExecutableURLs() {
        let doc = MarkdownDocument("[bad](javascript:alert) [file](file:///etc/passwd) [ok](https://example.com) ![image](file:///private/photo.png)")
        let runs = doc.blocks.flatMap { Array($0.text.runs) }
        XCTAssertEqual(runs.compactMap(\.link), [URL(string: "https://example.com")!])
        XCTAssertTrue(runs.compactMap(\.imageURL).isEmpty)
        XCTAssertTrue(String(doc.blocks[0].text.characters).contains("image"))
    }

    func testLargePlainTextFallsBackWithoutTruncation() {
        let source = String(repeating: "中文 **原文**\n", count: 30_000)
        let doc = MarkdownDocument(source)
        XCTAssertEqual(doc.blocks.count, 1)
        XCTAssertEqual(String(doc.blocks[0].text.characters), source)
    }
}
