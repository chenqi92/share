import SwiftUI

struct SettingsPage: View {
    private struct Row: Identifiable {
        let id = UUID()
        let label: String
        let english: String
        let value: String
        let kind: Kind

        enum Kind { case display, path, accept, network, screensaver }
    }

    private var rows: [Row] {
        [
            .init(label: "显示名",      english: "DISPLAY NAME",  value: MockData.settings.displayName, kind: .display),
            .init(label: "保存位置",    english: "SAVE PATH",     value: MockData.settings.savePath,    kind: .path),
            .init(label: "自动接受",    english: "AUTO ACCEPT",   value: MockData.settings.autoAccept,  kind: .accept),
            .init(label: "网络",        english: "NETWORK",       value: MockData.settings.network,     kind: .network),
            .init(label: "屏保",        english: "SCREENSAVER",   value: MockData.settings.screensaver, kind: .screensaver),
        ]
    }

    @FocusState private var focusedRow: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text("设置")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(MeshDropColor.dpaper)
                Text("· SETTINGS")
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(MeshDropColor.dpaperMute)
                Spacer()
                HStack(spacing: 10) {
                    Chip(text: "● LAN ONLY", tone: .lime, mono: true, size: 16)
                    Chip(text: "E2E", tone: .outline, mono: true, size: 16)
                    Chip(text: "tvOS 17+", tone: .outline, mono: true, size: 16)
                }
            }

            MeshAsciiDivider(label: "可见性 · 安全 · 行为 · BEHAVIOR")

            VStack(spacing: 18) {
                ForEach(rows) { row in
                    rowView(row)
                        .focused($focusedRow, equals: row.id)
                }
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
    }

    private func rowView(_ row: Row) -> some View {
        let focused = focusedRow == row.id
        return Button { } label: {
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

                Text("→")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(MeshDropColor.dpaperMute)
                    .frame(width: 36)
            }
            .padding(.horizontal, 28).padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MeshDropColor.dink2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MeshDropColor.dpaper.opacity(focused ? 0.95 : 0.0), lineWidth: 6)
            )
            .scaleEffect(focused ? 1.03 : 1.0)
            .animation(.spring(response: 0.30, dampingFraction: 0.78), value: focused)
        }
        .buttonStyle(.plain)
    }

    private var fingerprintBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("本机指纹 · DEVICE FINGERPRINT")
                .monoTag()
            Text(MockData.me.fingerprintShort)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(MeshDropColor.lime)
            Text("加密用 · 不要在直播间念出来")
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(MeshDropColor.dpaperMute)
        }
    }
}
