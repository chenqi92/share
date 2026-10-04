#if os(macOS) || os(iOS)
import SwiftUI

public struct MarkdownContentView: View {
    private let source: String
    @State private var document: MarkdownDocument?

    public init(_ source: String) { self.source = source }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let document {
                ForEach(document.blocks) { MarkdownBlockView(block: $0) }
            } else {
                Text(verbatim: source)
            }
        }
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: source) {
            let source = source
            let parsed = await Task.detached(priority: .userInitiated) { MarkdownDocument(source) }.value
            guard !Task.isCancelled else { return }
            document = parsed
        }
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownDocument.Block

    @ViewBuilder var body: some View {
        switch block.kind {
        case .header(let level):
            inline(block.text).font(.system(size: CGFloat(max(16, 28 - level * 2)), weight: .bold))
        case .codeBlock(let language):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(verbatim: language ?? "").font(.caption.monospaced()).opacity(0.65)
                    Spacer()
                    CopyTextButton(String(block.text.characters))
                        .font(.caption)
                }
                ScrollView(.horizontal) {
                    Text(verbatim: String(block.text.characters))
                        .font(.system(.body, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: true)
                }
            }
            .padding(10)
            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
        case .orderedList, .unorderedList:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(block.children) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: marker(for: item)).monospacedDigit().frame(minWidth: 16, alignment: .trailing)
                        MarkdownBlockView(block: item)
                    }
                }
            }
        case .listItem:
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(block.children.enumerated()), id: \.element.id) { index, child in
                    if index == 0, let task = taskText(child.text) {
                        inline(task.text)
                    } else {
                        MarkdownBlockView(block: child)
                    }
                }
            }
        case .blockQuote:
            HStack(alignment: .top, spacing: 10) {
                Rectangle().fill(.primary.opacity(0.25)).frame(width: 3)
                children
            }
            .fixedSize(horizontal: false, vertical: true)
        case .thematicBreak:
            Divider()
        case .table(let columns):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(block.children) { row in
                        GridRow {
                            ForEach(columns.indices, id: \.self) { index in
                                let cell = row.children.first { $0.kind == .tableCell(columnIndex: index) }
                                inline(cell?.text ?? AttributedString())
                                    .fontWeight(row.kind == .tableHeaderRow ? .semibold : .regular)
                                    .padding(8)
                                    .frame(minWidth: 80, alignment: alignment(for: index, columns: columns))
                                    .overlay(Rectangle().stroke(.primary.opacity(0.15), lineWidth: 0.5))
                            }
                        }
                    }
                }
            }
        default:
            inline(block.text)
            if !block.children.isEmpty { children }
        }
    }

    private var children: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(block.children) { MarkdownBlockView(block: $0) }
        }
    }

    private func marker(for item: MarkdownDocument.Block) -> String {
        if let text = item.children.first?.text, let task = taskText(text) { return task.checked ? "☑" : "☐" }
        if case .orderedList = block.kind, case .listItem(let ordinal) = item.kind { return "\(ordinal)." }
        return "•"
    }

    private func taskText(_ text: AttributedString) -> (checked: Bool, text: AttributedString)? {
        let plain = String(text.characters)
        guard plain.hasPrefix("[ ] ") || plain.hasPrefix("[x] ") || plain.hasPrefix("[X] ") else { return nil }
        let start = text.characters.index(text.startIndex, offsetBy: 4)
        return (!plain.hasPrefix("[ ]"), AttributedString(text[start...]))
    }

    private func alignment(for index: Int, columns: [PresentationIntent.TableColumn]) -> Alignment {
        switch columns[index].alignment {
        case .center: return .center
        case .right: return .trailing
        default: return .leading
        }
    }

    private func styled(_ text: AttributedString) -> AttributedString {
        var value = text
        for run in text.runs where run.inlinePresentationIntent?.contains(.code) == true {
            value[run.range].font = .system(.body, design: .monospaced)
            value[run.range].backgroundColor = .primary.opacity(0.08)
        }
        return value
    }

    private func inline(_ text: AttributedString) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(styled(text))
            ForEach(Array(text.runs.enumerated()), id: \.offset) { _, run in
                if let url = run.imageURL {
                    Link(destination: url) {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Image(systemName: "photo").padding()
                        }
                        .frame(maxHeight: 280)
                    }
                }
            }
        }
    }
}
#endif
