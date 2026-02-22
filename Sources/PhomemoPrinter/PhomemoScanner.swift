import Foundation
import CoreBluetooth
import Combine

/// Scans for nearby Phomemo printers via BLE.
///
/// Usage:
/// ```swift
/// let scanner = PhomemoScanner()
/// let printers = try await scanner.scan(timeout: 5.0)
/// ```
public final class PhomemoScanner: @unchecked Sendable {
    private let centralManager: BLECentralManager

    /// Published list of discovered printers, updated during scanning.
    @Published public private(set) var discoveredPrinters: [DiscoveredPrinter] = []

    /// Optional callback for ALL discovered BLE peripherals (for debugging).
    /// Called with (name, identifier, serviceUUIDs).
    public var onAnyPeripheralDiscovered: ((String?, UUID, [CBUUID]) -> Void)?

    public init() {
        self.centralManager = BLECentralManager()
    }

    /// Scan for Phomemo printers.
    ///
    /// - Parameters:
    ///   - timeout: How long to scan, in seconds. Defaults to 5.0.
    ///   - model: Optional model filter. If nil, discovers all supported models.
    /// - Returns: Array of discovered printers.
    public func scan(
        timeout: TimeInterval = 5.0,
        model: PrinterModel? = nil
    ) async throws -> [DiscoveredPrinter] {
        try await centralManager.waitForPowerOn()

        discoveredPrinters = []
        var results: [DiscoveredPrinter] = []
        var seen = Set<UUID>()
        let lock = NSLock()

        // Scan with all known Phomemo service UUIDs (AF30 for T02, FEE7 for M04S)
        // Pass nil to scan unfiltered — ensures we catch all Phomemo variants
        await centralManager.scan(
            serviceUUIDs: nil,
            timeout: timeout
        ) { [weak self] peripheral, advertisementData, rssi in
            guard let self else { return }

            // Skip duplicates
            lock.lock()
            let isNew = seen.insert(peripheral.identifier).inserted
            lock.unlock()
            guard isNew else { return }

            // Determine printer name
            let name = peripheral.name
                ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)

            // Debug callback for all peripherals
            let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
            DispatchQueue.main.async {
                self.onAnyPeripheralDiscovered?(name, peripheral.identifier, serviceUUIDs)
            }

            // Detect model from name
            guard let detectedModel = DiscoveredPrinter.detectModel(from: name) else { return }

            // Apply model filter if specified
            if let filterModel = model, detectedModel != filterModel { return }

            let printer = DiscoveredPrinter(
                id: peripheral.identifier,
                name: name ?? "Phomemo",
                model: detectedModel,
                rssi: rssi.intValue
            )

            lock.lock()
            results.append(printer)
            lock.unlock()

            DispatchQueue.main.async {
                self.discoveredPrinters.append(printer)
            }
        }

        // Return the thread-safe results array instead of the async-updated property
        return results
    }

    /// Access the underlying BLE central manager (for use by PhomemoPrinter).
    internal var bleManager: BLECentralManager { centralManager }
}
