import Foundation
import CoreBluetooth

/// A Phomemo printer discovered during BLE scanning.
public struct DiscoveredPrinter: Identifiable, Sendable {
    /// Unique identifier for this discovered printer (CBPeripheral UUID).
    public let id: UUID

    /// The advertised name of the printer.
    public let name: String

    /// The detected printer model based on the advertised name.
    public let model: PrinterModel

    /// Signal strength at discovery time.
    public let rssi: Int

    /// The underlying CBPeripheral identifier (same as `id`).
    public var peripheralIdentifier: UUID { id }

    public init(id: UUID, name: String, model: PrinterModel, rssi: Int) {
        self.id = id
        self.name = name
        self.model = model
        self.rssi = rssi
    }

    /// Attempt to detect the printer model from its advertised name.
    public static func detectModel(from name: String?) -> PrinterModel? {
        guard let name = name?.uppercased() else { return nil }
        // T02 variants
        if name.contains("T02") { return .t02 }
        // M04S / M04AS variants
        if name.contains("M04S") || name.contains("M04AS") { return .m04s }
        // Generic Phomemo — default to T02 (most common)
        if name.contains("PHOMEMO") { return .t02 }
        return nil
    }
}
