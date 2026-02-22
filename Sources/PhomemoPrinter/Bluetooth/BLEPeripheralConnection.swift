import Foundation
import CoreBluetooth
import Combine

/// Manages the BLE connection to a specific Phomemo printer peripheral.
///
/// Handles service/characteristic discovery, notifications, and data writing
/// (including chunked writes for M04S).
final class BLEPeripheralConnection: NSObject, @unchecked Sendable {
    let peripheral: CBPeripheral
    let profile: PrinterProfile

    private let queue = DispatchQueue(label: "com.phomemo.ble.peripheral", qos: .userInitiated)

    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristics: [CBCharacteristic] = []

    // Continuations
    private var serviceDiscoveryContinuation: CheckedContinuation<Void, Error>?
    private var characteristicDiscoveryContinuation: CheckedContinuation<Void, Error>?

    // Status publisher
    private let statusSubject = PassthroughSubject<PrinterStatus, Never>()
    var statusPublisher: AnyPublisher<PrinterStatus, Never> {
        statusSubject.eraseToAnyPublisher()
    }

    // Notification data publisher (raw bytes)
    private let notificationSubject = PassthroughSubject<[UInt8], Never>()
    var notificationPublisher: AnyPublisher<[UInt8], Never> {
        notificationSubject.eraseToAnyPublisher()
    }

    init(peripheral: CBPeripheral, profile: PrinterProfile) {
        self.peripheral = peripheral
        self.profile = profile
        super.init()
        self.peripheral.delegate = self
    }

    /// Discover the printer's BLE service and characteristics.
    func discoverServices() async throws {
        // Discover services
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: PhomemoError.notConnected)
                    return
                }
                self.serviceDiscoveryContinuation = continuation
                self.peripheral.discoverServices([self.profile.serviceUUID])
            }
        }

        // Discover characteristics
        guard let service = peripheral.services?.first(where: { $0.uuid == profile.serviceUUID }) else {
            throw PhomemoError.serviceNotFound
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: PhomemoError.notConnected)
                    return
                }
                self.characteristicDiscoveryContinuation = continuation
                self.peripheral.discoverCharacteristics(nil, for: service)
            }
        }

        // Validate write characteristic was found
        guard writeCharacteristic != nil else {
            throw PhomemoError.characteristicNotFound
        }

        // Enable notifications
        for char in notifyCharacteristics {
            peripheral.setNotifyValue(true, for: char)
        }
    }

    /// Send initialization commands to the printer.
    func sendInitCommands() async throws {
        for command in profile.initCommands {
            try await writeData(Data(command), withResponse: false)
            try await Task.sleep(nanoseconds: BLEConstants.initCommandDelayMs * 1_000_000)
        }
    }

    /// Write data to the printer's write characteristic.
    func writeData(_ data: Data, withResponse: Bool = false) async throws {
        guard let char = writeCharacteristic else {
            throw PhomemoError.characteristicNotFound
        }

        let writeType: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse

        switch profile.writeStrategy {
        case .bulk:
            await writeBulk(data: data, characteristic: char, type: writeType)
        case .chunked(let chunkSize, let burstCount, let delayMs):
            await writeChunked(
                data: data,
                characteristic: char,
                type: writeType,
                chunkSize: chunkSize,
                burstCount: burstCount,
                delayMs: delayMs
            )
        }
    }

    /// Write all data at once (T02 style).
    private func writeBulk(data: Data, characteristic: CBCharacteristic, type: CBCharacteristicWriteType) async {
        let mtu = peripheral.maximumWriteValueLength(for: type)
        var offset = 0

        while offset < data.count {
            let chunkSize = min(mtu, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset + chunkSize))
            peripheral.writeValue(chunk, for: characteristic, type: type)
            offset += chunkSize

            if offset < data.count {
                try? await Task.sleep(nanoseconds: BLEConstants.writeChunkDelayMs * 1_000_000)
            }
        }
    }

    /// Write data in chunked bursts with delays (M04S style).
    private func writeChunked(
        data: Data,
        characteristic: CBCharacteristic,
        type: CBCharacteristicWriteType,
        chunkSize: Int,
        burstCount: Int,
        delayMs: Int
    ) async {
        var offset = 0
        var burstCounter = 0

        while offset < data.count {
            let size = min(chunkSize, data.count - offset)
            let chunk = data.subdata(in: offset..<(offset + size))
            peripheral.writeValue(chunk, for: characteristic, type: type)
            offset += size
            burstCounter += 1

            if burstCounter >= burstCount && offset < data.count {
                burstCounter = 0
                try? await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEPeripheralConnection: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let continuation = serviceDiscoveryContinuation else { return }
        serviceDiscoveryContinuation = nil

        if let error {
            continuation.resume(throwing: PhomemoError.connectionFailed(underlying: error))
            return
        }

        guard peripheral.services?.contains(where: { $0.uuid == profile.serviceUUID }) == true else {
            continuation.resume(throwing: PhomemoError.serviceNotFound)
            return
        }

        continuation.resume()
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let continuation = characteristicDiscoveryContinuation else { return }
        characteristicDiscoveryContinuation = nil

        if let error {
            continuation.resume(throwing: PhomemoError.connectionFailed(underlying: error))
            return
        }

        guard let chars = service.characteristics else {
            continuation.resume(throwing: PhomemoError.characteristicNotFound)
            return
        }

        for char in chars {
            if char.uuid == profile.writeCharacteristicUUID {
                writeCharacteristic = char
            }
            if profile.notifyCharacteristicUUIDs.contains(char.uuid) && char.properties.contains(.notify) {
                notifyCharacteristics.append(char)
            }
        }

        continuation.resume()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let data = characteristic.value else { return }
        let bytes = [UInt8](data)

        notificationSubject.send(bytes)

        if let status = PrinterStatus.from(notificationData: bytes) {
            statusSubject.send(status)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Notification state updated — no action needed
    }
}
