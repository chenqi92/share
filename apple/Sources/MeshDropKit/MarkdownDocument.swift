import Foundation

struct MarkdownDocument: Sendable {
    struct Block: Identifiable, Sendable {
        let id: Int
        let kind: PresentationIntent.Kind
        var text: AttributedString
        var children: [Block]
    }

    let blocks: [Block]

    init(_ source: String) {
        guard source.utf8.count <= 200_000,
              let parsed = try? AttributedString(markdown: source, options: .init(interpretedSyntax: .full)) else {
            blocks = [Block(id: 0, kind: .paragraph, text: AttributedString(source), children: [])]
            return
        }
        var roots: [Builder] = []
        var nodes: [Int: Builder] = [:]
        for run in parsed.runs {
            let path = run.presentationIntent?.components.reversed().map { $0 } ?? []
            var parent: Builder?
            for intent in path {
                if let existing = nodes[intent.identity] {
                    parent = existing
                } else {
                    let node = Builder(id: intent.identity, kind: intent.kind)
                    nodes[intent.identity] = node
                    if let parent { parent.children.append(node) } else { roots.append(node) }
                    parent = node
                }
            }
            if parent == nil {
                let node = Builder(id: -roots.count - 1, kind: .paragraph)
                roots.append(node)
                parent = node
            }
            var text = AttributedString(parsed[run.range])
            text.presentationIntent = nil
            if run.inlinePresentationIntent?.contains(.softBreak) == true {
                text = AttributedString("\n")
            }
            if let link = text.link, !Self.isSafeLink(link) { text.link = nil }
            if let image = text.imageURL, !Self.isWebURL(image) { text.imageURL = nil }
            parent?.text.append(text)
        }
        blocks = roots.map { $0.block(depth: 0) }
    }

    static func isWebURL(_ url: URL) -> Bool {
        ["https", "http"].contains(url.scheme?.lowercased() ?? "") && url.host != nil
    }

    static func isSafeLink(_ url: URL) -> Bool {
        isWebURL(url) || url.scheme?.lowercased() == "mailto"
    }

    private final class Builder {
        let id: Int
        let kind: PresentationIntent.Kind
        var text = AttributedString()
        var children: [Builder] = []

        init(id: Int, kind: PresentationIntent.Kind) {
            self.id = id
            self.kind = kind
        }

        func block(depth: Int) -> Block {
            // Bound view nesting while keeping deeply nested content readable.
            if depth >= 16 {
                var flattened = text
                var pending = Array(children.reversed())
                while let node = pending.popLast() {
                    if !flattened.characters.isEmpty { flattened.append(AttributedString("\n")) }
                    flattened.append(node.text)
                    pending.append(contentsOf: node.children.reversed())
                }
                return Block(id: id, kind: .paragraph, text: flattened, children: [])
            }
            return Block(id: id, kind: kind, text: text, children: children.map { $0.block(depth: depth + 1) })
        }
    }
}
