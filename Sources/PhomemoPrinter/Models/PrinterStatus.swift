import Foundation

/// Status conditions reported by the printer via BLE notifications.
public struct PrinterStatus: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let normal            = PrinterStatus([])
    public static let overheating       = PrinterStatus(rawValue: 1 << 0)
    public static let coverOpen         = PrinterStatus(rawValue: 1 << 1)
    public static let noPaper           = PrinterStatus(rawValue: 1 << 2)
    public static let printComplete     = PrinterStatus(rawValue: 1 << 3)
    public static let cancelled         = PrinterStatus(rawValue: 1 << 4)

    /// Parse a notification payload from the printer.
    /// The status is encoded in bytes at index 1 and 2.
    public static func from(notificationData bytes: [UInt8]) -> PrinterStatus? {
        guard bytes.count > 2 else { return nil }

        let category = bytes[1]
        let code = bytes[2]

        switch (category, code) {
        // Temperature
        case (3, 0xA9): return .overheating
        case (3, 0xA8): return .normal  // temperature normal
        // Cover
        case (5, 0x99): return .coverOpen
        case (5, 0x98): return .normal  // cover closed
        // Paper
        case (6, 0x88): return .noPaper
        case (6, 0x89): return .normal  // paper present
        // Print
        case (11, 0xB8): return .cancelled
        case (15, 0x0C): return .printComplete
        default: return nil
        }
    }

    public var isReady: Bool {
        !contains(.overheating) && !contains(.coverOpen) && !contains(.noPaper)
    }
}
