import SwiftUI
import MeshDropKit

struct SettingsPage: View {
    @EnvironmentObject private var engine: ShareEngine

    private struct Row: Identifiable {
        let id = UUID()
        let label: String
        let english: String
        let value: String
        let kind: Kind

        enum Kind { case display, network, savePath, behavior, resetIdentity }
    }

    private var rows: [Row] {
        [
            .init(label: L10n.settingsRowDisplayName,   english: L10n.settingsRowDisplayNameEn,
                  value: engine.displayName, kind: .display),
            .init(label: L10n.settingsRowSavePath, english: L10n.settingsRowSavePathEn,
                  value: L10n.settingsRowSavePathValue, kind: .savePath),
            .init(label: L10n.settingsRowNetwork,     english: L10n.settingsRowNetworkEn,
                  value: "Wi-Fi · LAN ONLY · _meshdrop._tcp", kind: .network),
            .init(label: L10n.settingsRowBehavior,     english: L10n.settingsRowBehaviorEn,
                  value: L10n.settingsRowBehaviorValue, kind: .behavior),
            .init(label: L10n.settingsRowReset, english: L10n.settingsRowResetEn,
                  value: L10n.settingsRowResetValue, kind: .resetIdentity),
        ]
    }

    @FocusState private var focusedRow: UUID?
    @State private var editingName: Bool = false
    @State private var nameDraft: String = ""
    @State private var confirmingReset: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MeshAsciiDivider(label: L10n.settingsDivider)

            VStack(spacing: 18) {
                ForEach(rows) { row in
                    rowView(row)
                        .focused($focusedRow, equals: row.id)
                }
            }

            if editingName {
                nameEditor
            }

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 28) {
                fingerprintBlock
                Spacer()
                RemoteHint(items: [
                    .init(glyph: "↕", label: L10n.hintSelect),
                    .init(glyph: "OK", label: L10n.hintEdit),
                    .init(glyph: "TV", label: L10n.hintReturn),
                ])
            }
        }
        .confirmationDialog(
            L10n.settingsResetConfirm,
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(L10n.settingsResetAction, role: .destructive) { engine.resetIdentity() }
            Button(L10n.commonCancel, role: .cancel) {}
        }
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.settingsNameEditorTag)
                .monoTag()
            TextField(L10n.settingsNamePlaceholder, text: $nameDraft)
                .font(.system(size: 22, weight: .semibold))
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MeshDropColor.dink3)
                )
                .submitLabel(.done)
                .onSubmit(commitName)
            HStack(spacing: 12) {
                Button(action: commitName) {
                    Text(L10n.commonSave)
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(MeshDropColor.lime)
                        .foregroundStyle(MeshDropColor.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button(action: { editingName = false }) {
                    Text(L10n.commonCancel)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(MeshDropColor.dink3)
                        .foregroundStyle(MeshDropColor.dpaper)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MeshDropColor.dink2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MeshDropColor.lime.opacity(0.4), lineWidth: 1.5)
        )
    }

    private func commitName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { engine.displayName = trimmed }
        editingName = false
    }

    private func rowView(_ row: Row) -> some View {
        let focused = focusedRow == row.id
        return InvisibleFocusButton(isFocused: $focusedRow, value: row.id) {
            handleRowAction(row)
        } content: {
            HStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.label)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                    Text("· \(row.english)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(MeshDropColor.dpaperMute)
                }
                .frame(width: 260, alignment: .leading)

                Spacer()

                Text(row.value)
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(MeshDropColor.dpaper)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)

                Text("→")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(MeshDropColor.dpaperMute)
                    .frame(width: 36)
            }
            .padding(.horizontal, 28).padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(focused ? MeshDropColor.dink3 : MeshDropColor.dink2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .inset(by: 1)
                    .strokeBorder(focused ? MeshDropColor.dpaper.opacity(0.9) : MeshDropColor.dline,
                                  lineWidth: focused ? 2 : 1)
            )
            .offset(x: focused ? 8 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: focused)
        }
    }

    private func handleRowAction(_ row: Row) {
        switch row.kind {
        case .display:
            nameDraft = engine.displayName
            editingName = true
        case .resetIdentity:
            confirmingReset = true
        case .network, .savePath, .behavior:
            break
        }
    }

    private var fingerprintBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.settingsFingerprintTag)
                .monoTag()
            Text(shortFingerprint)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(MeshDropColor.lime)
            Text(L10n.settingsFingerprintHint)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(MeshDropColor.dpaperMute)
        }
    }

    private var shortFingerprint: String {
        let fp = engine.identity.fingerprint.uppercased()
        let groups = stride(from: 0, to: min(16, fp.count), by: 4).map { i -> String in
            let s = fp.index(fp.startIndex, offsetBy: i)
            let e = fp.index(s, offsetBy: 4, limitedBy: fp.endIndex) ?? fp.endIndex
            return String(fp[s..<e])
        }
        return groups.joined(separator: " · ")
    }
}
