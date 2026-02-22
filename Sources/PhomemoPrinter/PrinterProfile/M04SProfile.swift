import Foundation
import CoreBluetooth

/// Printer profile for the Phomemo M04S.
///
/// - Print width: 1232 dots (154 bytes)
/// - Resolution: ~300 DPI
/// - Write style: Chunked (205 bytes, 3-burst, 50ms delay)
/// - Byte escaping: None
struct M04SProfile: PrinterProfile {
    let model = PrinterModel.m04s

    let scanServiceUUID = CBUUID(string: "FEE7")
    let serviceUUID = CBUUID(string: "FF00")
    let writeCharacteristicUUID = CBUUID(string: "FF02")
    let notifyCharacteristicUUIDs = [CBUUID(string: "FF01"), CBUUID(string: "FF03")]

    let printWidthDots = 1232
    let printWidthBytes = 154
    let maxLinesPerChunk = 65535 // Send full height in one raster command
    let requiresByteEscaping = false
    let writeStrategy: WriteStrategy = .chunked(chunkSize: 205, burstCount: 3, delayMs: 50)

    /// M04S initialization: density, heat, init, disable compression.
    let initCommands: [[UInt8]] = [
        [0x1F, 0x11, 0x02, 0x04], // Set density
        [0x1F, 0x11, 0x37, 0x50], // Set heat (0x50 = 80)
        [0x1F, 0x11, 0x0B],       // Initialize
        [0x1F, 0x11, 0x35, 0x00], // Disable compression
    ]

    let imageHeader: [UInt8] = [
        0x1B, 0x40,               // ESC @ — Initialize printer
        0x1F, 0x11, 0x02, 0x04,   // Set density
    ]

    let imageFooter: [UInt8] = [
        0x1B, 0x64, 0x02, // ESC d 2 — Feed 2 lines
        0x1B, 0x64, 0x02, // ESC d 2 — Feed 2 lines
    ]
}
