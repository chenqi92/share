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
            .init(label: "显示名",   english: "DISPLAY NAME",
                  value: engine.displayName, kind: .display),
            .init(label: "保存位置", english: "SAVE PATH",
                  value: "本机 Documents/MeshDrop/<对端>/", kind: .savePath),
            .init(label: "网络",     english: "NETWORK",
                  value: "Wi-Fi · LAN ONLY · _meshdrop._tcp", kind: .network),
            .init(label: "行为",     english: "BEHAVIOR",
                  value: "只接收 · 不发送（tvOS）", kind: .behavior),
            .init(label: "重置身份", english: "RESET IDENTITY",
                  value: "对端需重新配对", kind: .resetIdentity),
        ]
    }

    @FocusState private var focusedRow: UUID?
    @State private var editingName: Bool = false
    @State private var nameDraft: String = ""
    @State private var confirmingReset: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            MeshAsciiDivider(label: "可见性 · 安全 · 行为 · BEHAVIOR")

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
                    .init(glyph: "↕", label: "选择"),
                    .init(glyph: "OK", label: "修改"),
                    .init(glyph: "TV", label: "返回"),
                ])
            }
        }
        .confirmationDialog(
            "重置身份会生成新的 ID 与密钥对，所有已配对的对端会把本机视为新设备需要重新配对。继续？",
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button("重置身份", role: .destructive) { engine.resetIdentity() }
            Button("取消", role: .cancel) {}
        }
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("修改显示名 · DISPLAY NAME")
                .monoTag()
            TextField("Living Room TV", text: $nameDraft)
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
                    Text("保存")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(MeshDropColor.lime)
                        .foregroundStyle(MeshDropColor.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button(action: { editingName = false }) {
                    Text("取消")
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
            Text("本机指纹 · DEVICE FINGERPRINT")
                .monoTag()
            Text(shortFingerprint)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(MeshDropColor.lime)
            Text("身份校验用 · 当面比对")
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
