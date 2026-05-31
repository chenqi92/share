import SwiftUI

struct OnboardingPage: View {
    private var screenshotTime: Double? {
        ProcessInfo.processInfo.environment["MESHDROP_SCREENSHOT"] == "1" ? 0.6 : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MeshDropLockup(size: 26)
                Spacer()
                Chip(text: "STEP 2 / 4", tone: .outline, mono: true)
                Text("跳过")
                    .font(MeshDropFont.body(size: 12))
                    .foregroundStyle(MeshDropColor.textMuted)
                    .padding(.leading, 6)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)

            HStack(spacing: 32) {
                // 左侧渲染图
                VStack(alignment: .center, spacing: 14) {
                    Radar(devices: OnboardingPage.demoDevices,
                          variant: .sweep,
                          staticTime: screenshotTime)
                        .frame(width: 400, height: 400)
                    HStack(spacing: 8) {
                        stepDot(active: false)
                        stepDot(active: true)
                        stepDot(active: false)
                        stepDot(active: false)
                    }
                }
                .frame(maxWidth: .infinity)

                // 右侧文案
                VStack(alignment: .leading, spacing: 18) {
                    Text("拖即发送")
                        .font(MeshDropFont.hero(48))
                        .tracking(-1.5)
                        .foregroundStyle(MeshDropColor.textPrimary)
                    Text("Drag → Drop. 就这么简单。")
                        .font(MeshDropFont.hero(28))
                        .tracking(-0.5)
                        .foregroundStyle(MeshDropColor.textMuted)

                    Text("任何文件、图片、文字便签。把它拖到 Discovery 雷达上的设备头像，对端立刻收到接受请求。")
                        .font(MeshDropFont.body(size: 14))
                        .foregroundStyle(MeshDropColor.textPrimary)
                        .frame(width: 380, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        feature("●", "雷达式自动发现局域网内设备",  MeshDropColor.limeDeep)
                        feature("●", "端到端加密 · X25519 + ChaCha20", MeshDropColor.flame)
                        feature("●", "剪贴板跨设备同步 · 仅本人",     MeshDropColor.sky)
                        feature("●", "常驻菜单栏 · ⌥⇧S 一键发送",     MeshDropColor.ink)
                    }

                    HStack(spacing: 10) {
                        Text("上一步")
                            .font(MeshDropFont.body(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(MeshDropColor.divider, lineWidth: 1)
                            )
                            .foregroundStyle(MeshDropColor.textSecondary)
                        Text("继续 ⏎")
                            .font(MeshDropFont.body(size: 13, weight: .semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(MeshDropColor.ink)
                            )
                            .foregroundStyle(MeshDropColor.paper)
                    }
                    .padding(.top, 4)
                }
                .frame(width: 420)
            }
            .padding(.horizontal, 40)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Text("ESC")
                    .font(MeshDropFont.mono(size: 10, weight: .semibold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(MeshDropColor.divider, lineWidth: 0.5)
                    )
                Text("跳过新手指引")
                    .font(MeshDropFont.body(size: 11))
                    .foregroundStyle(MeshDropColor.textMuted)
                Spacer()
                Text("MeshDrop · 局域网分享 · 不上云")
                    .font(MeshDropFont.mono(size: 10))
                    .foregroundStyle(MeshDropColor.textMuted)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MeshDropColor.background)
    }

    @ViewBuilder
    private func feature(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(MeshDropFont.mono(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(MeshDropFont.body(size: 13))
                .foregroundStyle(MeshDropColor.textPrimary)
        }
    }

    @ViewBuilder
    private func stepDot(active: Bool) -> some View {
        Capsule()
            .fill(active ? MeshDropColor.ink : MeshDropColor.divider)
            .frame(width: active ? 22 : 6, height: 6)
    }
}

private extension OnboardingPage {
    /// onboarding 雷达背景的演示设备（不连真实 engine，纯装饰）。
    static let demoDevices: [MockDevice] = [
        MockDevice(id: "demo-1", name: "Lily · MacBook",    who: "李莉", kind: .mac,     dist: 0.55, angle: 35,  color: Color(red: 1.00, green: 0.71, blue: 0.63), initials: "LL", os: "macOS",  rtt: 18, online: true),
        MockDevice(id: "demo-2", name: "Kun · Pixel 8",     who: "坤",   kind: .android, dist: 0.78, angle: 110, color: Color(red: 0.72, green: 0.90, blue: 0.78), initials: "K",  os: "Pixel",  rtt: 32, online: true),
        MockDevice(id: "demo-3", name: "Jiawei · iPad",     who: "嘉伟", kind: .ipad,    dist: 0.40, angle: 200, color: Color(red: 0.78, green: 0.72, blue: 1.00), initials: "JW", os: "iPadOS", rtt: 14, online: true),
        MockDevice(id: "demo-4", name: "Meng Xi · iPhone",  who: "孟茜", kind: .ios,     dist: 0.62, angle: 265, color: Color(red: 1.00, green: 0.85, blue: 0.44), initials: "MX", os: "iOS",    rtt: 26, online: true),
    ]
}
