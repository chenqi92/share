import SwiftUI
import MeshDropKit

struct PairingPage: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var engine = ShareEngine.shared
    @State private var requesting = Set<String>()
    @State private var results: [String: Bool] = [:]

    var body: some View {
        PageScroll {
            VStack(alignment: .leading, spacing: 18) {
                Text("pairing.title")
                    .font(MeshDropFont.hero(34))
                Text("pairing.thisDevice").meshTag()
                Text(state.localFingerprintFull)
                    .font(MeshDropFont.mono(size: 13, weight: .semibold))
                    .textSelection(.enabled)

                Divider()
                let devices = engine.devices.filter { $0.discoveryEndpoint != nil }
                if devices.isEmpty {
                    Text("discovery.empty.title").foregroundStyle(MeshDropColor.textMuted)
                }
                ForEach(devices, id: \.conversationID) { device in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name).font(.headline)
                            Text(device.humanFingerprint)
                                .font(MeshDropFont.mono(size: 11))
                                .textSelection(.enabled)
                        }
                        Spacer()
                        if requesting.contains(device.fingerprint) {
                            ProgressView().controlSize(.small)
                            Text("pairing.waiting")
                        } else {
                            if engine.trusted.contains(where: { $0.fingerprint == device.fingerprint }) {
                                Label("receive.paired", systemImage: "checkmark.shield")
                            } else {
                                if results[device.fingerprint] == false {
                                    Text("pairing.notRemembered")
                                }
                                Button("pairing.request") {
                                    requesting.insert(device.fingerprint)
                                    Task {
                                        results[device.fingerprint] = await engine.requestPairing(to: device)
                                        requesting.remove(device.fingerprint)
                                    }
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(MeshDropColor.cardBg, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MeshDropColor.background)
    }
}
