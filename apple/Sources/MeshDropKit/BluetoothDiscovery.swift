#if os(iOS) || os(macOS)
import Foundation
import CoreBluetooth
import OSLog

private let bluetoothLog = Logger(subsystem: "com.welape.meshdrop", category: "Bluetooth")

struct BluetoothAdvertisement: Codable {
    let id: String
    let name: String
    let os: DeviceOS
    let model: String?
    let fingerprint: String
    let psm: UInt16
    let version: Int

    func device(peripheralID: UUID) -> Device? {
        func isHexID(_ value: String) -> Bool {
            value.utf8.count == 32 && value.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0) || (65...70).contains($0)
            }
        }
        guard version == 1, psm > 0, isHexID(id), isHexID(fingerprint), name.utf8.count <= 256 else { return nil }
        var device = Device(id: id, name: name, os: os, model: model, fingerprint: fingerprint, port: 0)
        device.bluetoothID = peripheralID
        device.bluetoothPSM = psm
        return device
    }
}

/// GATT carries discovery metadata only; file and chat frames use a Bluetooth
/// L2CAP stream, independent of IP connectivity and Wi-Fi.
@MainActor
final class BluetoothDiscovery: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    private static let service = CBUUID(string: "C0FDE001-92DD-4CF2-9D6E-7AB8E880A202")
    private static let metadata = CBUUID(string: "C0FDE002-92DD-4CF2-9D6E-7AB8E880A201")
    private static let secureChannel = CBUUID(string: "C0FDE003-92DD-4CF2-9D6E-7AB8E880A201")
    private let identity: Identity
    private let name: String
    private let model: String?
    private var central: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var devices: [UUID: Device] = [:]
    private var opens: [UUID: (UUID, CheckedContinuation<StreamTransport, Error>)] = [:]
    private var channelPSMs: [UUID: UInt16] = [:]
    private var secureCharacteristics: [UUID: CBCharacteristic] = [:]
    private var openQueue: [UUID: [(UUID, UInt16, CheckedContinuation<StreamTransport, Error>)]] = [:]
    private var connecting = Set<UUID>()
    private var retryAfter: [UUID: Date] = [:]
    private var psm: CBL2CAPPSM?
    private var metadataValue: Data?
    private var visible = true
    private var stopped = false
    var onDevices: (([Device]) -> Void)?
    var onIncoming: ((Connection) -> Void)?
    var onStatus: ((String) -> Void)?

    init(identity: Identity, name: String, model: String?) {
        self.identity = identity
        self.name = name
        self.model = model
        super.init()
    }

    func start(visible: Bool) {
        stopped = false
        self.visible = visible
        central = CBCentralManager(delegate: self, queue: .main)
        peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
    }

    func setVisible(_ visible: Bool) {
        self.visible = visible
        guard peripheralManager?.state == .poweredOn else { return }
        if visible, metadataValue != nil { advertise() }
        else { peripheralManager.stopAdvertising() }
    }

    func stop() {
        stopped = true
        central?.stopScan()
        peripheralManager?.stopAdvertising()
        if let psm { peripheralManager?.unpublishL2CAPChannel(psm) }
        peripheralManager?.removeAllServices()
        psm = nil
        metadataValue = nil
        for peripheral in peripherals.values { central?.cancelPeripheralConnection(peripheral) }
        failAll()
        peripherals.removeAll()
        devices.removeAll()
        onDevices?([])
    }

    func connection(to device: Device) -> Connection {
        Connection(bluetooth: { [weak self] in
            guard let self else { throw ConnectionError.routeUnavailable }
            return try await self.open(device)
        })
    }

    private func open(_ device: Device) async throws -> StreamTransport {
        guard !stopped, central.state == .poweredOn,
              let id = device.bluetoothID, let psm = device.bluetoothPSM,
              let peripheral = peripherals[id], peripheral.state == .connected else { throw ConnectionError.routeUnavailable }
        let token = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            openQueue[id, default: []].append((token, psm, continuation))
            beginNextOpen(peripheral)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(90))
                guard let self else { return }
                if self.opens[id]?.0 == token {
                    self.opens.removeValue(forKey: id)?.1.resume(throwing: ConnectionError.timeout)
                    self.central.cancelPeripheralConnection(peripheral)
                } else if let index = self.openQueue[id]?.firstIndex(where: { $0.0 == token }) {
                    self.openQueue[id]?.remove(at: index).2.resume(throwing: ConnectionError.timeout)
                }
            }
        }
    }

    private func beginNextOpen(_ peripheral: CBPeripheral) {
        let id = peripheral.identifier
        guard opens[id] == nil, let next = openQueue[id]?.first else { return }
        openQueue[id]?.removeFirst()
        opens[id] = (next.0, next.2)
        channelPSMs[id] = next.1
        // L2CAP requires an already encrypted link. Read a protected attribute to
        // let CoreBluetooth perform system pairing only when the user sends.
        if let secure = secureCharacteristics[id] {
            bluetoothLog.info("authorizing encrypted L2CAP PSM=\(next.1)")
            peripheral.readValue(for: secure)
        } else {
            bluetoothLog.error("encrypted channel attribute missing")
            opens.removeValue(forKey: id)?.1.resume(throwing: ConnectionError.routeUnavailable)
            channelPSMs[id] = nil
            central.cancelPeripheralConnection(peripheral)
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !stopped else { return }
        reportState(central.state)
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [Self.service], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        } else {
            failAll()
            devices.removeAll()
            peripherals.removeAll()
            secureCharacteristics.removeAll()
            connecting.removeAll()
            onDevices?([])
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard !stopped else { return }
        reportState(peripheral.state)
        if peripheral.state == .poweredOn {
            guard psm == nil else { return }
            peripheral.removeAllServices()
            peripheral.publishL2CAPChannel(withEncryption: true)
        } else {
            psm = nil
            metadataValue = nil
        }
    }

    private func reportState(_ state: CBManagerState) {
        let key: String.LocalizationValue
        switch state {
        case .poweredOn: key = "bluetooth.ready"
        case .poweredOff: key = "bluetooth.off"
        case .unauthorized: key = "bluetooth.denied"
        case .unsupported: key = "bluetooth.unsupported"
        default: key = "bluetooth.starting"
        }
        onStatus?(String(localized: key, bundle: .module))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        guard !stopped, error == nil else {
            if let error { onStatus?(error.localizedDescription) }
            return
        }
        psm = PSM
        bluetoothLog.info("published encrypted L2CAP PSM=\(PSM)")
        let metadata = BluetoothAdvertisement(id: identity.id, name: String(name.prefix(64)), os: .current,
                                             model: model, fingerprint: identity.fingerprint, psm: PSM, version: 1)
        metadataValue = try? JSONEncoder().encode(metadata)
        let service = CBMutableService(type: Self.service, primary: true)
        service.characteristics = [
            CBMutableCharacteristic(type: Self.metadata, properties: [.read], value: nil, permissions: [.readable]),
            CBMutableCharacteristic(type: Self.secureChannel, properties: [.read], value: nil, permissions: [.readable, .readEncryptionRequired])
        ]
        peripheral.add(service)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard !stopped else { return }
        if let error { onStatus?(error.localizedDescription); return }
        if visible { advertise() }
    }

    private func advertise() {
        peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Self.service]])
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let value = request.characteristic.uuid == Self.secureChannel ? Data([1]) : metadataValue
        guard visible, [Self.metadata, Self.secureChannel].contains(request.characteristic.uuid), let data = value else {
            peripheral.respond(to: request, withResult: .readNotPermitted); return
        }
        guard request.offset <= data.count else {
            peripheral.respond(to: request, withResult: .invalidOffset); return
        }
        request.value = data.subdata(in: request.offset..<data.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard !stopped, peripherals.count < 32, !connecting.contains(peripheral.identifier),
              peripherals[peripheral.identifier]?.state != .connected,
              (retryAfter[peripheral.identifier] ?? .distantPast) < Date() else { return }
        peripherals[peripheral.identifier] = peripheral
        connecting.insert(peripheral.identifier)
        peripheral.delegate = self
        central.connect(peripheral)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, self.connecting.contains(peripheral.identifier) else { return }
            self.central.cancelPeripheralConnection(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard !stopped else { central.cancelPeripheralConnection(peripheral); return }
        peripheral.discoverServices([Self.service])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == Self.service }) else {
            central.cancelPeripheralConnection(peripheral); return
        }
        peripheral.discoverCharacteristics([Self.metadata, Self.secureChannel], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard invalidatedServices.contains(where: { $0.uuid == Self.service }) else { return }
        devices[peripheral.identifier] = nil
        secureCharacteristics[peripheral.identifier] = nil
        onDevices?(Array(devices.values))
        central.cancelPeripheralConnection(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let metadata = service.characteristics?.first(where: { $0.uuid == Self.metadata }) else {
            central.cancelPeripheralConnection(peripheral); return
        }
        secureCharacteristics[peripheral.identifier] = service.characteristics?.first(where: { $0.uuid == Self.secureChannel })
        bluetoothLog.info("discovered GATT secure=\(self.secureCharacteristics[peripheral.identifier] != nil)")
        peripheral.readValue(for: metadata)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == Self.secureChannel {
            let id = peripheral.identifier
            guard !stopped, opens[id] != nil, let psm = channelPSMs[id] else { return }
            if let error {
                bluetoothLog.error("encrypted attribute failed: \(error.localizedDescription, privacy: .public)")
                opens.removeValue(forKey: id)?.1.resume(throwing: error)
                channelPSMs[id] = nil
                beginNextOpen(peripheral)
            } else {
                bluetoothLog.info("encrypted attribute ready; opening L2CAP PSM=\(psm)")
                peripheral.openL2CAPChannel(psm)
            }
            return
        }
        guard !stopped, characteristic.uuid == Self.metadata, error == nil,
              let data = characteristic.value, data.count <= 2048,
              let metadata = try? JSONDecoder().decode(BluetoothAdvertisement.self, from: data),
              metadata.id != identity.id,
              let device = metadata.device(peripheralID: peripheral.identifier) else {
            central.cancelPeripheralConnection(peripheral); return
        }
        connecting.remove(peripheral.identifier)
        bluetoothLog.info("discovered L2CAP PSM=\(metadata.psm)")
        devices[peripheral.identifier] = device
        onDevices?(Array(devices.values))
    }

    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        channelPSMs[peripheral.identifier] = nil
        guard let pending = opens.removeValue(forKey: peripheral.identifier) else {
            channel?.inputStream.close(); channel?.outputStream.close(); return
        }
        defer { beginNextOpen(peripheral) }
        guard let channel, error == nil else {
            let nsError = (error ?? ConnectionError.routeUnavailable) as NSError
            bluetoothLog.error("open L2CAP failed: \(nsError.domain, privacy: .public) \(nsError.code) \(nsError.localizedDescription, privacy: .public)")
            pending.1.resume(throwing: error ?? ConnectionError.routeUnavailable); return
        }
        bluetoothLog.info("outgoing L2CAP ready PSM=\(channel.psm)")
        pending.1.resume(returning: transport(channel))
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard !stopped, visible, let channel, error == nil else {
            channel?.inputStream.close(); channel?.outputStream.close(); return
        }
        let stream = transport(channel)
        bluetoothLog.info("incoming L2CAP ready PSM=\(channel.psm)")
        onIncoming?(Connection(bluetooth: { stream }))
    }

    private func transport(_ channel: CBL2CAPChannel) -> StreamTransport {
        StreamTransport(input: channel.inputStream, output: channel.outputStream, owner: channel, name: "Bluetooth L2CAP")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        disconnected(peripheral, error: error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        disconnected(peripheral, error: error)
    }

    private func disconnected(_ peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier
        connecting.remove(id)
        devices[id] = nil
        peripherals[id] = nil
        secureCharacteristics[id] = nil
        channelPSMs[id] = nil
        retryAfter[id] = Date().addingTimeInterval(3)
        opens.removeValue(forKey: id)?.1.resume(throwing: error ?? ConnectionError.alreadyClosed)
        for pending in openQueue.removeValue(forKey: id) ?? [] {
            pending.2.resume(throwing: error ?? ConnectionError.alreadyClosed)
        }
        onDevices?(Array(devices.values))
    }

    private func failAll() {
        let pending = Array(opens.values)
        let queued = openQueue.values.flatMap { $0 }
        openQueue.removeAll()
        for entry in queued { entry.2.resume(throwing: ConnectionError.routeUnavailable) }
        opens.removeAll()
        channelPSMs.removeAll()
        for (_, continuation) in pending { continuation.resume(throwing: ConnectionError.routeUnavailable) }
    }
}
#endif
