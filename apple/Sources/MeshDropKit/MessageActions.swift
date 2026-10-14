#if os(macOS) || os(iOS)
import SwiftUI
import QuickLook
#if os(macOS)
import AppKit
#endif

@MainActor
public final class ContentPreviewPresenter: ObservableObject {
    struct TextPreview: Identifiable {
        let id = UUID()
        let text: String
    }

    @Published fileprivate var fileURL: URL?
    @Published fileprivate var textPreview: TextPreview?
    @Published fileprivate var unavailable = false

    public init() {}

    fileprivate func show(text: String) {
        guard fileURL == nil, textPreview == nil else { return }
        textPreview = TextPreview(text: text)
    }

    fileprivate func show(file: URL?) {
        guard fileURL == nil, textPreview == nil else { return }
        guard let file = LocalFileContent.readableURL(file) else {
            unavailable = true
            return
        }
        if let text = LocalFileContent.markdownText(file) {
            show(text: text)
        } else {
            fileURL = file
        }
    }
}

public extension View {
    /// Keep one presentation host alive for the whole conversation.
    func contentPreviewHost(_ presenter: ContentPreviewPresenter) -> some View {
        modifier(ContentPreviewHost(presenter: presenter))
    }

    func messageActions(text: String? = nil, fileURL: URL? = nil,
                        completed: Bool = false, historyID: UUID? = nil,
                        retry: (() -> Void)? = nil) -> some View {
        modifier(MessageActions(text: text, fileURL: fileURL, completed: completed,
                                historyID: historyID, retry: retry))
    }
}

private struct ContentPreviewHost: ViewModifier {
    @ObservedObject var presenter: ContentPreviewPresenter

    func body(content: Content) -> some View {
        content
            .environmentObject(presenter)
            .quickLookPreview($presenter.fileURL)
            .sheet(item: $presenter.textPreview) { TextContentDetail($0.text) }
            .alert(L10n.t("content.fileUnavailable"), isPresented: $presenter.unavailable) {
                Button(L10n.t("content.close"), role: .cancel) {}
            }
    }
}

private struct MessageActions: ViewModifier {
    let text: String?
    let fileURL: URL?
    let completed: Bool
    let historyID: UUID?
    let retry: (() -> Void)?
    @EnvironmentObject private var preview: ContentPreviewPresenter
    @State private var confirmingDeletion = false
    @State private var deleting = false
    @State private var failure: String?

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .gesture(TapGesture().onEnded {
                if completed { preview.show(file: fileURL) }
            }, including: text == nil ? .all : .subviews)
            .contextMenu {
                if let text {
                    Button(L10n.t("content.copy"), systemImage: "doc.on.doc") { SystemClipboard.copy(text) }
                    Button(L10n.t("content.viewText"), systemImage: "doc.text.magnifyingglass") { preview.show(text: text) }
                } else if completed {
                    Button(L10n.t("content.preview"), systemImage: "eye") { preview.show(file: fileURL) }
                    if let file = LocalFileContent.readableURL(fileURL) {
                        ShareLink(item: file) { Label(L10n.t("content.share"), systemImage: "square.and.arrow.up") }
                        #if os(macOS)
                        Button(L10n.t("content.copyFile"), systemImage: "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.writeObjects([file as NSURL])
                        }
                        Button(L10n.t("content.reveal"), systemImage: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([file])
                        }
                        #endif
                    }
                }
                if let retry {
                    Button(L10n.t("content.retry"), systemImage: "arrow.clockwise", action: retry)
                }
                if historyID != nil {
                    Divider()
                    Button(L10n.t("history.delete"), systemImage: "trash", role: .destructive) { confirmingDeletion = true }
                        .disabled(deleting)
                }
            }
            .confirmationDialog(L10n.t("history.delete.title"), isPresented: $confirmingDeletion, titleVisibility: .visible) {
                Button(L10n.t("history.delete"), role: .destructive) {
                    guard let historyID else { return }
                    deleting = true
                    Task { @MainActor in
                        do { try await ShareEngine.shared.deleteHistoryItem(historyID) }
                        catch { failure = error.localizedDescription }
                        deleting = false
                    }
                }
                Button(L10n.t("common.cancel"), role: .cancel) {}
            } message: { Text(L10n.t("history.delete.detail")) }
            .alert(L10n.t("history.delete.failed"), isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button(L10n.t("common.close")) { failure = nil }
            } message: { Text(failure ?? "") }
    }
}
#endif
