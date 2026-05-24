import SwiftUI

struct PairingPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(
                tag: "待配对 · PAIRING · 把代码发给对方",
                title: "把代码发给 ",
                titleAccentSuffix: "对方"
            ) {
                HStack(spacing: 10) {
                    Chip(text: "LAN ONLY", tone: .lime, mono: true, size: 14)
                    Chip(text: "E2E · CHACHA20", tone: .outline, mono: true, size: 14)
                    Chip(text: "65 秒后过期", tone: .outline, mono: true, size: 14)
                }
            }

            HStack(alignment: .top, spacing: 64) {
                // 左：大字 6 字符代码 + 指纹
                VStack(alignment: .leading, spacing: 28) {
                    Text(MockData.pairingCode)
                        .font(.system(size: 144, weight: .black, design: .monospaced))
                        .tracking(4)
                        .foregroundStyle(MeshDropColor.lime)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 36)
                        .background(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .fill(MeshDropColor.dink2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(MeshDropColor.lime.opacity(0.4), lineWidth: 2)
                        )

                    MeshAsciiDivider(label: "指纹 · FINGERPRINT · 比对一致才允许")

                    Text(MockData.me.fingerprintFull)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(MeshDropColor.dpaper)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // 右：QR + 步骤
                VStack(spacing: 22) {
                    MeshQRCode(content: "meshdrop://pair/\(MockData.pairingCode)/\(MockData.me.fingerprintShort)", size: 320)

                    VStack(spacing: 4) {
                        Text("扫码 · SCAN")
                            .monoTag()
                        Text("用对方手机相机即可")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(MeshDropColor.dpaperDim)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        stepLine("1", "对方打开 MeshDrop")
                        stepLine("2", "选「扫码加入」或输代码")
                        stepLine("3", "两端指纹一致 → 允许")
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(MeshDropColor.dink2)
                    )
                }
                .frame(width: 420)
            }
        }
    }

    private func stepLine(_ n: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Text(n)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundStyle(MeshDropColor.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(MeshDropColor.lime))
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MeshDropColor.dpaper)
        }
    }
}
