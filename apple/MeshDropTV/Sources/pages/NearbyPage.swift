import SwiftUI

struct NearbyPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageHeader(
                tag: "附近 · NEARBY · READY 待机",
                title: "这台电视，谁都能 ",
                titleAccentSuffix: "ping."
            ) {
                HStack(spacing: 10) {
                    Chip(text: "● 客厅 LAN", tone: .lime, mono: true, size: 14)
                    Chip(text: "5 台可见", tone: .outline, mono: true, size: 14)
                }
            }

            HStack(alignment: .top, spacing: 56) {
                // 左：巨型雷达
                MeshRadar(devices: MockData.devices, diameter: 640)
                    .frame(width: 640, height: 640)

                // 右：配对入口 + 设备 row
                VStack(alignment: .leading, spacing: 24) {
                    Text("在你手机上打开 MeshDrop，选「Living Room TV」。\n照片、视频、文档都可以推到这块屏上。")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(MeshDropColor.dpaperDim)
                        .lineSpacing(4)

                    MeshAsciiDivider(label: "或 · OR · 扫码加入 · SCAN")

                    HStack(spacing: 28) {
                        MeshQRCode(content: "meshdrop://pair/LR4K7M/" + MockData.me.fingerprintShort, size: 220)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("代码 · CODE")
                                .monoTag()
                            Text(MockData.pairingCode)
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundStyle(MeshDropColor.lime)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Text("无 App · 浏览器进")
                                .monoTag()
                            Text(MockData.me.ip)
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundStyle(MeshDropColor.dpaper)
                        }
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("附近 5 台 · NEARBY · 客厅可见")
                            .monoTag(MeshDropColor.dpaperDim)
                        HStack(spacing: 16) {
                            ForEach(MockData.devices) { d in
                                VStack(spacing: 6) {
                                    Avatar(initials: d.initials, color: d.color, size: 56, ring: MeshDropColor.lime)
                                    Text(d.who)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(MeshDropColor.dpaper)
                                    Text("\(d.os) · \(d.rtt)ms")
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(MeshDropColor.dpaperMute)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
