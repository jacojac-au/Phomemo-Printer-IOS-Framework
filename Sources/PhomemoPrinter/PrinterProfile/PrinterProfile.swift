import Foundation
import CoreBluetooth

/// Write strategy for sending data to the printer over BLE.
public enum WriteStrategy: Sendable {
    /// Send the entire payload at once (T02 style).
    case bulk
    /// Chunked writes with specified chunk size, burst count, and inter-burst delay.
    case chunked(chunkSize: Int, burstCount: Int, delayMs: Int)
}

/// Protocol defining model-specific behavior for a Phomemo printer.
///
/// Each printer model implements this protocol, providing its UUIDs, print width,
/// initialization commands, image header/footer, and encoding parameters.
/// Adding a new model = one new struct conforming to this protocol.
protocol PrinterProfile: Sendable {
    /// The printer model this profile represents.
    var model: PrinterModel { get }

    /// BLE service UUID used for scanning/advertising.
    var scanServiceUUID: CBUUID { get }

    /// BLE service UUID for the operational service.
    var serviceUUID: CBUUID { get }

    /// BLE characteristic UUID for writing data.
    var writeCharacteristicUUID: CBUUID { get }

    /// BLE characteristic UUID(s) for notifications.
    var notifyCharacteristicUUIDs: [CBUUID] { get }

    /// Print width in dots.
    var printWidthDots: Int { get }

    /// Print width in bytes.
    var printWidthBytes: Int { get }

    /// Maximum number of raster lines per chunk/command.
    var maxLinesPerChunk: Int { get }

    /// Whether bitmap bytes need escaping (e.g. 0x0A → 0x14 on T02).
    var requiresByteEscaping: Bool { get }

    /// Write strategy for BLE data transfer.
    var writeStrategy: WriteStrategy { get }

    /// Commands to send during printer initialization/handshake.
    var initCommands: [[UInt8]] { get }

    /// Header bytes prepended before raster data.
    var imageHeader: [UInt8] { get }

    /// Footer bytes appended after raster data.
    var imageFooter: [UInt8] { get }
}

extension PrinterProfile {
    /// Detect and return the appropriate profile for a given printer model.
    static func profile(for model: PrinterModel) -> PrinterProfile {
        switch model {
        case .t02: return T02Profile()
        case .m04s: return M04SProfile()
        }
    }
}
