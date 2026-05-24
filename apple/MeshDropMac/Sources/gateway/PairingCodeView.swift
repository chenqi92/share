import SwiftUI
import AppKit

/// Settings → Web 访问 段。显示 URL / 6 字符配对码 / 开关 / 端口。
struct PairingCodeView: View {
    @EnvironmentObject var gateway: GatewayService
    @State private var portText: String = "7384"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Web 浏览器入口")
                    .font(MeshDropFont.body(size: 12.5))
                    .foregroundStyle(MeshDropColor.textPrimary)
                Spacer()
                MeshToggle(on: Binding(
                    get: { gateway.enabled },
                    set: { gateway.toggle(enabled: $0) }
                ))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Rectangle().fill(MeshDropColor.divider).frame(height: 1)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("URL")
                            .font(MeshDropFont.mono(size: 10, weight: .bold))
                            .foregroundStyle(MeshDropColor.textMuted)
                        HStack(spacing: 8) {
                            Text(gateway.displayURL)
                                .font(MeshDropFont.mono(size: 13, weight: .semibold))
                                .foregroundStyle(MeshDropColor.textPrimary)
                                .textSelection(.enabled)
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(gateway.displayURL, forType: .string)
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.borderless)
                        }
                        Text(gateway.isRunning
                             ? "● 已运行 · listening :\(gateway.port)"
                             : (gateway.enabled ? "○ 未运行" : "○ 已关闭"))
                            .font(MeshDropFont.mono(size: 10))
                            .foregroundStyle(gateway.isRunning ? MeshDropColor.limeDeep : MeshDropColor.textMuted)
                    }
                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("配对码 · PAIRING CODE")
                            .font(MeshDropFont.mono(size: 10, weight: .bold))
                            .foregroundStyle(MeshDropColor.textMuted)
                        HStack(spacing: 6) {
                            Text(gateway.displayCode)
                                .font(MeshDropFont.display(size: 22, weight: .bold))
                                .tracking(3)
                                .foregroundStyle(MeshDropColor.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(MeshDropColor.lime)
                                )
                            Button { gateway.rotateCode() } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .padding(.horizontal, 14)

                HStack(spacing: 12) {
                    Text("端口")
                        .font(MeshDropFont.body(size: 12))
                        .foregroundStyle(MeshDropColor.textPrimary)
                    TextField("", text: $portText, onCommit: {
                        if let n = UInt16(portText.trimmingCharacters(in: .whitespaces)), n > 0 {
                            gateway.setPort(n)
                        } else {
                            portText = "\(gateway.port)"
                        }
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(MeshDropFont.mono(size: 12, weight: .semibold))
                    .frame(width: 90)
                    Spacer()
                    Text("浏览器首次访问需输入上方的 6 字符配对码（24h 有效）")
                        .font(MeshDropFont.body(size: 11))
                        .foregroundStyle(MeshDropColor.textMuted)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
            .padding(.top, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MeshDropColor.cardBg2)
        )
        .onAppear { portText = "\(gateway.port)" }
    }
}
