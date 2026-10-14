#if os(macOS) || os(iOS)
import SwiftUI
import QuickLook
#if os(macOS)
import AppKit
#endif

public struct CopyTextButton: View {
    private let text: String
    @State private var copied = false

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Button {
            SystemClipboard.copy(text)
            copied = true
        } label: {
            Label(String(localized: copied ? "content.copied" : "content.copy", bundle: .module),
                  systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.plain)
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            copied = false
        }
    }
}

public struct TextContentActions: View {
    private let text: String
    @State private var showingDetail = false

    public init(_ text: String) { self.text = text }

    public var body: some View {
        HStack(spacing: 12) {
            CopyTextButton(text)
            Button {
                showingDetail = true
            } label: {
                Label(String(localized: "content.viewText", bundle: .module), systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingDetail) { TextContentDetail(text) }
    }
}

struct TextContentDetail: View {
    let text: String
    @Environment(\.dismiss) private var dismiss
    @State private var showSource = false

    init(_ text: String) { self.text = text }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Picker(String(localized: "content.display", bundle: .module), selection: $showSource) {
                    Text(String(localized: "content.preview", bundle: .module)).tag(false)
                    Text(String(localized: "content.source", bundle: .module)).tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 210)
                Spacer(minLength: 0)
                CopyTextButton(text)
                Button(String(localized: "content.close", bundle: .module)) { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding()
            Divider()
            ScrollView {
                Group {
                    if showSource {
                        Text(verbatim: text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    } else {
                        MarkdownContentView(text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 720, minHeight: 420, idealHeight: 600)
        #endif
    }
}

public struct FileContentActions: View {
    private let url: URL?
    private let completed: Bool
    @State private var previewURL: URL?
    @State private var unavailable = false
    @State private var markdownFile: MarkdownFile?

    private struct MarkdownFile: Identifiable {
        let id: URL
        let text: String
    }

    public init(url: URL?, completed: Bool) {
        self.url = url
        self.completed = completed
    }

    public var body: some View {
        HStack(spacing: 12) {
            if completed {
                Button {
                    if let file = readableURL {
                        if let text = LocalFileContent.markdownText(file) {
                            markdownFile = MarkdownFile(id: file, text: text)
                        } else {
                            previewURL = file
                        }
                    } else {
                        unavailable = true
                    }
                } label: {
                    Label(String(localized: "content.preview", bundle: .module), systemImage: "eye")
                }
                .buttonStyle(.plain)
                if let file = readableURL {
                    ShareLink(item: file) {
                        Label(String(localized: "content.share", bundle: .module), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                    #if os(macOS)
                    Menu {
                        Button(String(localized: "content.copyFile", bundle: .module), systemImage: "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.writeObjects([file as NSURL])
                        }
                        Button(String(localized: "content.reveal", bundle: .module), systemImage: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([file])
                        }
                    } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    #endif
                }
            }
        }
        .quickLookPreview($previewURL)
        .sheet(item: $markdownFile) { TextContentDetail($0.text) }
        .alert(String(localized: "content.fileUnavailable", bundle: .module), isPresented: $unavailable) {
            Button(String(localized: "content.close", bundle: .module), role: .cancel) {}
        }
    }

    private var readableURL: URL? { LocalFileContent.readableURL(url) }
}
#endif
