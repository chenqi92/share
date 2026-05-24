import SwiftUI

struct NearbyPage: View {
    var body: some View {
        HStack(alignment: .top, spacing: 64) {
            // 左：巨型雷达
            VStack {
                Spacer()
                MeshRadar(devices: MockData.devices, diameter: 760)
                Spacer()
            }
            .frame(maxWidth: .infinity)

            // 右：hero 文案 + 配对入口
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 14) {
                    Circle().fill(MeshDropColor.lime).frame(width: 14, height: 14)
                    Text("READY · 待机")
                        .monoTag(MeshDropColor.lime)
                        .tracking(2.4)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("这台电视，")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                    HStack(spacing: 0) {
                        Text("谁都能 ")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(MeshDropColor.dpaper)
                        Text("ping.")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundStyle(MeshDropColor.lime)
                    }
                }

                Text("在你手机上打开 MeshDrop，选「Living Room TV」。\n照片、视频、文档都可以推到这块屏上。")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(MeshDropColor.dpaperDim)
                    .lineSpacing(6)
                    .padding(.top, 4)

                MeshAsciiDivider(label: "或 · OR · 扫码加入 · SCAN")
                    .padding(.vertical, 8)

                HStack(spacing: 32) {
                    MeshQRCode(content: "meshdrop://pair/LR4K7M/" + MockData.me.fingerprintShort, size: 240)
                    VStack(alignment: .leading, spacing: 14) {
                        Text("代码 · CODE")
                            .monoTag()
                        Text(MockData.pairingCode)
                            .font(.system(size: 56, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(MeshDropColor.lime)
                        Text("无 App · 浏览器进")
                            .monoTag()
                        Text(MockData.me.ip)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(MeshDropColor.dpaper)
                    }
                }

                Spacer(minLength: 24)

                VStack(alignment: .leading, spacing: 14) {
                    Text("附近 5 台 · NEARBY · 客厅可见")
                        .monoTag(MeshDropColor.dpaperDim)
                    HStack(spacing: 18) {
                        ForEach(MockData.devices) { d in
                            VStack(spacing: 8) {
                                Avatar(initials: d.initials, color: d.color, size: 64, ring: MeshDropColor.lime)
                                Text(d.who)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(MeshDropColor.dpaper)
                                Text("\(d.os) · \(d.rtt)ms")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(MeshDropColor.dpaperMute)
                            }
                        }
                    }
                }
            }
            .frame(width: 760, alignment: .leading)
        }
    }
}
