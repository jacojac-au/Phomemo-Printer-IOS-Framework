import Foundation

/// Supported Phomemo printer models.
public enum PrinterModel: String, Sendable, CaseIterable {
    case t02 = "T02"
    case m04s = "M04S"

    /// Print width in dots.
    public var printWidthDots: Int {
        switch self {
        case .t02: return 384
        case .m04s: return 1232
        }
    }

    /// Print width in bytes (dots / 8).
    public var printWidthBytes: Int {
        printWidthDots / 8
    }

    /// Approximate DPI.
    public var dpi: Int {
        switch self {
        case .t02: return 200
        case .m04s: return 300
        }
    }
}
