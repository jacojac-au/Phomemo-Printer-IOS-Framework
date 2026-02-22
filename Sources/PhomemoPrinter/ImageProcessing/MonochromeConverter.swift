import Foundation
import CoreGraphics

/// Converts grayscale pixels to monochrome using simple thresholding.
enum MonochromeConverter {
    /// Apply threshold to convert grayscale pixels to black or white.
    ///
    /// - Parameters:
    ///   - pixels: Grayscale pixel array (0-255).
    ///   - threshold: Values below this become black (0), above become white (255).
    /// - Returns: Modified pixel array with only 0 or 255 values.
    static func convert(pixels: inout [UInt8], threshold: UInt8 = 128) {
        for i in 0..<pixels.count {
            pixels[i] = pixels[i] < threshold ? 0 : 255
        }
    }
}
