import SwiftUI

struct PairingPage: View {
    var body: some View {
        HStack(alignment: .top, spacing: 64) {
            // 左：超大字号 6 字符代码
            VStack(alignment: .leading, spacing: 36) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("待配对 · PAIRING")
                        .monoTag(MeshDropColor.flame)
                    Text("把这串代码")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                    Text("发给对方")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                }

                Text(MockData.pairingCode)
                    .font(.system(size: 168, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(MeshDropColor.lime)
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
                    .padding(.top, 6)

                Text(MockData.me.fingerprintFull)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(MeshDropColor.dpaper)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Chip(text: "LAN ONLY", tone: .lime, mono: true, size: 16)
                    Chip(text: "E2E · CHACHA20", tone: .outline, mono: true, size: 16)
                    Chip(text: "65 秒后过期", tone: .outline, mono: true, size: 16)
                }
            }

            // 右：QR + 二维码提示
            VStack(spacing: 26) {
                MeshQRCode(content: "meshdrop://pair/\(MockData.pairingCode)/\(MockData.me.fingerprintShort)", size: 360)

                VStack(spacing: 6) {
                    Text("扫码 · SCAN")
                        .monoTag()
                    Text("用对方手机相机即可")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(MeshDropColor.dpaperDim)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 10) {
                    stepLine("1", "对方打开 MeshDrop")
                    stepLine("2", "选「扫码加入」或输代码")
                    stepLine("3", "两端指纹一致 → 允许")
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(MeshDropColor.dink2)
                )
            }
            .frame(width: 460)
        }
    }

    private func stepLine(_ n: String, _ text: String) -> some View {
        HStack(spacing: 16) {
            Text(n)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(MeshDropColor.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(MeshDropColor.lime))
            Text(text)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MeshDropColor.dpaper)
        }
    }
}
