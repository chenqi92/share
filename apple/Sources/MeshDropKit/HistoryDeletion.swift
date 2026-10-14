import Foundation
import SwiftUI

public struct HistoryDeleteButton: View {
    private let id: UUID
    @State private var confirming = false
    @State private var deleting = false
    @State private var failure: String?

    public init(id: UUID) { self.id = id }

    public var body: some View {
        Button { confirming = true } label: {
            Label(L10n.t("history.delete"), systemImage: "trash")
        }
        .buttonStyle(.plain)
        .disabled(deleting)
        .confirmationDialog(L10n.t("history.delete.title"), isPresented: $confirming, titleVisibility: .visible) {
            Button(L10n.t("history.delete"), role: .destructive) {
                deleting = true
                Task { @MainActor in
                    do { try await ShareEngine.shared.deleteHistoryItem(id) }
                    catch { failure = error.localizedDescription }
                    deleting = false
                }
            }
            Button(L10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.t("history.delete.detail"))
        }
        .alert(L10n.t("history.delete.failed"), isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button(L10n.t("common.close")) { failure = nil }
        } message: { Text(failure ?? "") }
    }
}

enum HistoryDeletion {
    static func removeAttachment(for item: HistoryItem, preserving others: [HistoryItem],
                                 attachmentsDirectory: URL) throws {
        guard let file = attachmentURL(for: item, preserving: others, attachmentsDirectory: attachmentsDirectory) else { return }
        let fm = FileManager.default
        if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
        let ownedDirectory = attachmentsDirectory.appendingPathComponent(item.id.uuidString)
        if file.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath() == ownedDirectory.standardizedFileURL.resolvingSymlinksInPath(),
           fm.fileExists(atPath: ownedDirectory.path),
           try fm.contentsOfDirectory(atPath: ownedDirectory.path).isEmpty {
            try fm.removeItem(at: ownedDirectory)
        }
    }

    static func attachmentURL(for item: HistoryItem, preserving others: [HistoryItem],
                              attachmentsDirectory: URL) -> URL? {
        guard case .file(_, _, let stored) = item.kind,
              let url = LocalFileContent.restoredURL(stored), url.isFileURL else { return nil }
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        guard !others.contains(where: {
            guard case .file(_, _, let other) = $0.kind else { return false }
            return LocalFileContent.restoredURL(other)?.standardizedFileURL.resolvingSymlinksInPath().path == path
        }) else { return nil }
        if item.direction == .incoming { return url }
        // Never delete the user's original outgoing attachment.
        let owned = attachmentsDirectory.appendingPathComponent(item.id.uuidString).standardizedFileURL.resolvingSymlinksInPath().path + "/"
        return path.hasPrefix(owned) ? url : nil
    }
}
