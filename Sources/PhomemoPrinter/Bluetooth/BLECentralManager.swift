import Foundation
import CoreBluetooth
import os

/// Async/await wrapper around CBCentralManager for BLE scanning and connection.
///
/// Uses `CheckedContinuation` to bridge delegate callbacks. Runs on a dedicated
/// serial DispatchQueue for thread safety. Retains discovered peripherals to
/// prevent deallocation.
final class BLECentralManager: NSObject, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.phomemo.printer", category: "BLE")
    private let queue = DispatchQueue(label: "com.phomemo.ble.central", qos: .userInitiated)
    private var centralManager: CBCentralManager!

    // Retain peripherals to prevent deallocation
    private var discoveredPeripherals: [UUID: CBPeripheral] = [:]

    // Continuations for async bridging
    private var powerOnContinuation: CheckedContinuation<Void, Error>?
    private var connectContinuation: CheckedContinuation<CBPeripheral, Error>?

    // Scan results callback
    private var onPeripheralDiscovered: ((CBPeripheral, [String: Any], NSNumber) -> Void)?

    // Connection state
    private var connectingPeripheral: CBPeripheral?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: queue)
    }

    /// Wait until Bluetooth is powered on.
    func waitForPowerOn() async throws {
        // Check on the BLE queue to avoid races
        let currentState: CBManagerState = await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                continuation.resume(returning: self?.centralManager.state ?? .unknown)
            }
        }

        Self.logger.debug("waitForPowerOn: current state = \(currentState.rawValue)")

        if currentState == .poweredOn {
            Self.logger.debug("Already powered on")
            return
        }

        switch currentState {
        case .unsupported:
            throw PhomemoError.bluetoothUnavailable
        case .unauthorized:
            throw PhomemoError.bluetoothUnauthorized
        case .poweredOff:
            throw PhomemoError.bluetoothPoweredOff
        default:
            break
        }

        // State is unknown/resetting — wait for delegate callback
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: PhomemoError.bluetoothUnavailable)
                    return
                }
                // Re-check on queue in case state changed
                if self.centralManager.state == .poweredOn {
                    continuation.resume()
                } else {
                    self.powerOnContinuation = continuation
                }
            }
        }
    }

    /// Scan for peripherals advertising the given service UUIDs.
    ///
    /// - Parameters:
    ///   - serviceUUIDs: Optional service UUIDs to filter on. Pass nil to scan for all.
    ///   - timeout: Scan duration in seconds.
    ///   - onDiscovered: Called for each discovered peripheral (on the BLE queue).
    func scan(
        serviceUUIDs: [CBUUID]?,
        timeout: TimeInterval,
        onDiscovered: @escaping @Sendable (CBPeripheral, [String: Any], NSNumber) -> Void
    ) async {
        Self.logger.debug("Starting scan, serviceUUIDs: \(serviceUUIDs?.map(\.uuidString) ?? ["nil/all"], privacy: .public), timeout: \(timeout)s")

        // Start scan on BLE queue
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                self?.onPeripheralDiscovered = onDiscovered
                self?.centralManager.scanForPeripherals(
                    withServices: serviceUUIDs,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
                )
                Self.logger.debug("scanForPeripherals called on BLE queue")
                continuation.resume()
            }
        }

        // Wait for timeout
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

        Self.logger.debug("Scan timeout reached, stopping scan")

        // Stop scan on BLE queue
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                self?.centralManager.stopScan()
                self?.onPeripheralDiscovered = nil
                continuation.resume()
            }
        }
    }

    /// Stop an active scan.
    func stopScan() {
        queue.async { [weak self] in
            self?.centralManager.stopScan()
            self?.onPeripheralDiscovered = nil
        }
    }

    /// Connect to a peripheral by its UUID.
    func connect(identifier: UUID) async throws -> CBPeripheral {
        // Look up peripheral on the BLE queue
        let peripheral: CBPeripheral = try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: PhomemoError.connectionFailed(underlying: nil))
                    return
                }
                if let p = self.discoveredPeripherals[identifier] {
                    continuation.resume(returning: p)
                } else {
                    let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: [identifier])
                    if let p = peripherals.first {
                        self.discoveredPeripherals[identifier] = p
                        continuation.resume(returning: p)
                    } else {
                        continuation.resume(throwing: PhomemoError.connectionFailed(underlying: nil))
                    }
                }
            }
        }
        return try await connectPeripheral(peripheral)
    }

    /// Connect to a specific CBPeripheral.
    private func connectPeripheral(_ peripheral: CBPeripheral) async throws -> CBPeripheral {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CBPeripheral, Error>) in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: PhomemoError.connectionFailed(underlying: nil))
                    return
                }
                self.connectContinuation = continuation
                self.connectingPeripheral = peripheral
                self.centralManager.connect(peripheral, options: [
                    CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                ])
            }
        }
    }

    /// Disconnect from a peripheral.
    func disconnect(_ peripheral: CBPeripheral) {
        queue.async { [weak self] in
            self?.centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    /// Retain a peripheral to prevent deallocation during scanning.
    func retainPeripheral(_ peripheral: CBPeripheral) {
        queue.async { [weak self] in
            self?.discoveredPeripherals[peripheral.identifier] = peripheral
        }
    }

    /// Clear all retained peripherals.
    func clearDiscoveredPeripherals() {
        queue.async { [weak self] in
            self?.discoveredPeripherals.removeAll()
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLECentralManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Self.logger.debug("centralManagerDidUpdateState: \(central.state.rawValue)")
        guard let continuation = powerOnContinuation else { return }
        powerOnContinuation = nil

        switch central.state {
        case .poweredOn:
            continuation.resume()
        case .unsupported:
            continuation.resume(throwing: PhomemoError.bluetoothUnavailable)
        case .unauthorized:
            continuation.resume(throwing: PhomemoError.bluetoothUnauthorized)
        case .poweredOff:
            continuation.resume(throwing: PhomemoError.bluetoothPoweredOff)
        default:
            break // Keep waiting
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "<unknown>"
        Self.logger.debug("Discovered: \(name, privacy: .public) (\(peripheral.identifier.uuidString.prefix(8))...) RSSI: \(RSSI)")
        discoveredPeripherals[peripheral.identifier] = peripheral
        onPeripheralDiscovered?(peripheral, advertisementData, RSSI)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let continuation = connectContinuation else { return }
        connectContinuation = nil
        connectingPeripheral = nil
        continuation.resume(returning: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let continuation = connectContinuation else { return }
        connectContinuation = nil
        connectingPeripheral = nil
        continuation.resume(throwing: PhomemoError.connectionFailed(underlying: error))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let continuation = connectContinuation {
            connectContinuation = nil
            connectingPeripheral = nil
            continuation.resume(throwing: PhomemoError.disconnected)
        }
    }
}
