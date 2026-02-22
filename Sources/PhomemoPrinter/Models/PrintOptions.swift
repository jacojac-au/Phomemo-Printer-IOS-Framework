import Foundation

/// Options for configuring a print job.
public struct PrintOptions: Sendable {
    /// Whether to use Floyd-Steinberg dithering (true) or simple threshold (false).
    public var dithered: Bool

    /// Threshold value (0-255) for monochrome conversion. Only used when `dithered` is false.
    public var threshold: UInt8

    /// Number of blank lines to feed after printing.
    public var feedLines: UInt8

    public init(dithered: Bool = true, threshold: UInt8 = 128, feedLines: UInt8 = 2) {
        self.dithered = dithered
        self.threshold = threshold
        self.feedLines = feedLines
    }

    /// Default print options with dithering enabled.
    public static let `default` = PrintOptions()
}
