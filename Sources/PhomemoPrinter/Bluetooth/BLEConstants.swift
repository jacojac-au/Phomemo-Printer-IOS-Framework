import Foundation
import CoreBluetooth

/// Common BLE constants used across the library.
enum BLEConstants {
    /// Advertised service UUID for Phomemo printers (T02).
    static let scanServiceUUID_AF30 = CBUUID(string: "AF30")

    /// Advertised service UUID for Phomemo printers (M04S).
    static let scanServiceUUID_FEE7 = CBUUID(string: "FEE7")

    /// HID service UUID (alternative scan filter for T02).
    static let hidServiceUUID = CBUUID(string: "1812")

    /// All known scan service UUIDs for Phomemo printers.
    static let allScanServiceUUIDs: [CBUUID] = [scanServiceUUID_AF30, scanServiceUUID_FEE7]

    /// Operational service UUID.
    static let serviceUUID = CBUUID(string: "FF00")

    /// Write characteristic UUID.
    static let writeCharUUID = CBUUID(string: "FF02")

    /// Notify characteristic UUIDs.
    static let notifyCharUUID_FF01 = CBUUID(string: "FF01")
    static let notifyCharUUID_FF03 = CBUUID(string: "FF03")

    /// Connection timeout in seconds.
    static let connectionTimeout: TimeInterval = 10.0

    /// Default scan timeout in seconds.
    static let defaultScanTimeout: TimeInterval = 5.0

    /// Delay between init command writes (milliseconds).
    static let initCommandDelayMs: UInt64 = 200

    /// Default MTU-based write delay (milliseconds).
    static let writeChunkDelayMs: UInt64 = 20
}
