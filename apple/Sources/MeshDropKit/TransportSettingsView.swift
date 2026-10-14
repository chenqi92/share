import SwiftUI

public struct TransportSettingsView: View {
    @ObservedObject private var engine: ShareEngine

    public init(engine: ShareEngine) { self.engine = engine }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(String(localized: "route.enableBluetooth", bundle: .module), isOn: $engine.bluetoothEnabled)
            HStack {
                Text(String(localized: "route.choose", bundle: .module))
                Spacer()
                Picker(String(localized: "route.choose", bundle: .module), selection: $engine.preferredRoute) {
                    ForEach(TransferRoute.allCases) { route in Text(route.title).tag(route) }
                }
                .labelsHidden()
                #if os(macOS)
                .pickerStyle(.segmented)
                .frame(maxWidth: 430)
                #else
                .pickerStyle(.menu)
                #endif
            }
            Text(String(localized: "route.detail", bundle: .module))
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if engine.bluetoothEnabled, !engine.bluetoothStatus.isEmpty {
                Text(engine.bluetoothStatus).font(.caption).foregroundStyle(.secondary)
            }
            if engine.preferredRoute == .peerToPeer, let error = engine.directDiscoveryError {
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button(String(localized: "route.retry", bundle: .module)) { engine.refreshDiscovery() }
            }
        }
    }
}
