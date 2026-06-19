import SwiftUI
import MeshDropKit

private enum PairingFocus: Hashable {
    case accept(UUID)
    case reject(UUID)
}

struct PairingPage: View {
    @EnvironmentObject private var engine: ShareEngine
    @FocusState private var focused: PairingFocus?

    var body: some View {
        HStack(alignment: .top, spacing: 64) {
            leftPanel
                .frame(maxWidth: .infinity, alignment: .leading)

            rightPanel
                .frame(width: 460)
        }
    }

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(shortCode)
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

            MeshAsciiDivider(label: L10n.pairingDividerFingerprint)

            Text(fullFingerprint)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(MeshDropColor.dpaper)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            if engine.pendingPairings.isEmpty {
                Text(L10n.pairingNoPending)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MeshDropColor.dpaperMute)
                    .padding(.top, 8)
            } else {
                ForEach(engine.pendingPairings) { req in
                    requestRow(req)
                }
            }

            // 发现层不可用（最常见：本地网络权限被拒）时给出明确提示，避免「二维码在、却永远等不到配对」。
            if let err = engine.lastError {
                Text(err)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MeshDropColor.flame)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
    }

    private var rightPanel: some View {
        VStack(spacing: 22) {
            MeshQRCode(content: pairURL, size: 320)

            VStack(spacing: 4) {
                Text(L10n.pairingScanTag)
                    .monoTag()
                Text(L10n.pairingScanHint)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MeshDropColor.dpaperDim)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                stepLine("1", L10n.pairingStep1)
                stepLine("2", L10n.pairingStep2)
                stepLine("3", L10n.pairingStep3)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MeshDropColor.dink2)
            )
        }
    }

    private func requestRow(_ req: PairingRequest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Avatar(initials: req.peer.displayInitials,
                       color: MeshDropColor.lime.opacity(0.85),
                       size: 56,
                       ring: MeshDropColor.lime)
                VStack(alignment: .leading, spacing: 4) {
                    Text(req.peer.name)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(MeshDropColor.dpaper)
                    Text(L10n.pairingPeerFingerprint(req.peer.humanFingerprint))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(MeshDropColor.dpaperMute)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                pairingCTA(.accept(req.id), title: L10n.pairingTrust, tone: .lime) {
                    engine.respondToPairing(req.id, decision: .trust)
                }
                pairingCTA(.reject(req.id), title: L10n.pairingReject, tone: .mute) {
                    engine.respondToPairing(req.id, decision: .reject)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MeshDropColor.dink2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MeshDropColor.lime.opacity(0.35), lineWidth: 1.5)
        )
    }

    @ViewBuilder
    private func pairingCTA(_ id: PairingFocus,
                            title: String,
                            tone: ChipTone,
                            action: @escaping () -> Void) -> some View {
        let isFocused = focused == id
        InvisibleFocusButton(isFocused: $focused, value: id, action: action) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tone == .lime ? MeshDropColor.ink : MeshDropColor.dpaper)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tone == .lime ? MeshDropColor.lime : MeshDropColor.dink3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .inset(by: 2)
                        .strokeBorder((tone == .lime ? MeshDropColor.ink : MeshDropColor.dpaper)
                            .opacity(isFocused ? 0.9 : 0.0), lineWidth: 3)
                )
                .animation(.easeInOut(duration: 0.18), value: isFocused)
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

    // MARK: - 派生

    private var shortCode: String {
        // 取本机指纹的前 6 个 hex 大写，用 · 分隔，作为人眼对齐的短码
        let fp = engine.identity.fingerprint.uppercased()
        let head = String(fp.prefix(6))
        let parts = stride(from: 0, to: head.count, by: 3).map { i -> String in
            let s = head.index(head.startIndex, offsetBy: i)
            let e = head.index(s, offsetBy: 3, limitedBy: head.endIndex) ?? head.endIndex
            return String(head[s..<e])
        }
        return parts.joined(separator: " · ")
    }

    private var fullFingerprint: String {
        // 把 32 hex 切成 8 组 4，每行 4 组
        let fp = engine.identity.fingerprint.uppercased()
        let groups = stride(from: 0, to: fp.count, by: 4).map { i -> String in
            let s = fp.index(fp.startIndex, offsetBy: i)
            let e = fp.index(s, offsetBy: 4, limitedBy: fp.endIndex) ?? fp.endIndex
            return String(fp[s..<e])
        }
        let first = groups.prefix(4).joined(separator: " · ")
        let second = groups.dropFirst(4).joined(separator: " · ")
        return second.isEmpty ? first : "\(first)\n\(second)"
    }

    private var pairURL: String {
        "meshdrop://device/\(engine.identity.id)/\(engine.identity.fingerprint)"
    }
}
