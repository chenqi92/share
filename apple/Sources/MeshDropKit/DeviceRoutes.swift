import Foundation

enum DeviceRoutes {
    static func currentDevice(for snapshot: Device, in devices: [Device]) -> Device? {
        devices.first { $0.conversationID == snapshot.conversationID }
    }

    static func merge(_ sources: [[Device]], preference: TransferRoute) -> [Device] {
        var merged: [String: Device] = [:]
        for device in sources.flatMap({ $0 }) {
            let key = device.conversationID
            if var existing = merged[key] {
                existing.discoveryEndpoint = existing.discoveryEndpoint ?? device.discoveryEndpoint
                existing.peerToPeerEndpoint = existing.peerToPeerEndpoint ?? device.peerToPeerEndpoint
                existing.bluetoothID = existing.bluetoothID ?? device.bluetoothID
                existing.bluetoothPSM = existing.bluetoothPSM ?? device.bluetoothPSM
                merged[key] = existing
            } else { merged[key] = device }
        }
        return merged.values.filter {
            preference == .automatic || $0.availableRoutes.contains(preference)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func select(_ device: Device, preference: TransferRoute) -> TransferRoute? {
        let available = device.availableRoutes
        if preference != .automatic { return available.contains(preference) ? preference : nil }
        return available.first
    }
}
