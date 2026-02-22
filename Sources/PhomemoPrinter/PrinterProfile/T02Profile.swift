import Foundation
import CoreBluetooth

/// Printer profile for the Phomemo T02.
///
/// - Print width: 384 dots (48 bytes)
/// - Resolution: ~200 DPI
/// - Write style: Single bulk write
/// - Byte escaping: 0x0A → 0x14
struct T02Profile: PrinterProfile {
    let model = PrinterModel.t02

    let scanServiceUUID = CBUUID(string: "AF30")
    let serviceUUID = CBUUID(string: "FF00")
    let writeCharacteristicUUID = CBUUID(string: "FF02")
    let notifyCharacteristicUUIDs = [CBUUID(string: "FF03")]

    let printWidthDots = 384
    let printWidthBytes = 48
    let maxLinesPerChunk = 256
    let requiresByteEscaping = true
    let writeStrategy: WriteStrategy = .bulk

    /// T02 initialization: request serial number, bitmap mode, paper and cover status.
    let initCommands: [[UInt8]] = [
        // "SSSGETSN\r\n"
        [0x53, 0x53, 0x53, 0x47, 0x45, 0x54, 0x53, 0x4E, 0x0D, 0x0A],
        // "SSSGETBMAPMODE\r\n"
        [0x53, 0x53, 0x53, 0x47, 0x45, 0x54, 0x42, 0x4D, 0x41, 0x50, 0x4D, 0x4F, 0x44, 0x45, 0x0D, 0x0A],
        // Ask paper status
        [0x1F, 0x11, 0x11],
        // Ask cover status
        [0x1F, 0x11, 0x12],
    ]

    /// ESC @ (init), ESC a 1 (center), custom density
    let imageHeader: [UInt8] = [
        0x1B, 0x40,       // ESC @ — Initialize printer
        0x1B, 0x61, 0x01, // ESC a 1 — Center alignment
        0x1F, 0x11, 0x02, 0x04, // Set density
    ]

    let imageFooter: [UInt8] = [
        0x1B, 0x64, 0x02, // ESC d 2 — Feed 2 lines
        0x1B, 0x64, 0x02, // ESC d 2 — Feed 2 lines
        0x1F, 0x11, 0x08, // Status request
        0x1F, 0x11, 0x0E, // Status request
        0x1F, 0x11, 0x07, // Status request
        0x1F, 0x11, 0x09, // Status request
    ]
}
